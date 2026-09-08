import "dart:async";
import "dart:convert";
import "dart:math" as math;

import "package:connectivity_plus/connectivity_plus.dart";
import "package:drift/drift.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../api/api_client.dart";
import "../api/api_exception.dart";
import "../auth/auth_state.dart";
import "../data/repositories.dart";
import "../db/app_database.dart";
import "../db/tables.dart";
import "../domain/batch_number_generator.dart";
import "outbox_repository.dart";

/// Result of one outbox send attempt, produced by the injected sender.
enum SendOutcome {
  /// 2xx — entry synced.
  success,

  /// Network error / timeout / 5xx — retry with backoff.
  retryable,

  /// 409 BATCH_NO_TAKEN on a batch entry — regenerate the number.
  batchNoTaken,

  /// Other 4xx — never retried.
  permanent,

  /// 401 — pause the drain and surface an auth event.
  authRequired,
}

class SendResult {
  const SendResult._(this.outcome, {this.response, this.code, this.statusCode});

  final SendOutcome outcome;

  /// Decoded JSON response body (success).
  final Map<String, dynamic>? response;

  /// Machine-readable error code from the API envelope (failure).
  final String? code;
  final int? statusCode;

  factory SendResult.success([Map<String, dynamic>? response]) =>
      SendResult._(SendOutcome.success, response: response);

  factory SendResult.retryable({String? code, int? statusCode}) =>
      SendResult._(SendOutcome.retryable, code: code, statusCode: statusCode);

  factory SendResult.batchNoTaken() =>
      const SendResult._(SendOutcome.batchNoTaken, code: "BATCH_NO_TAKEN");

  factory SendResult.permanent(String code, {int? statusCode}) =>
      SendResult._(SendOutcome.permanent, code: code, statusCode: statusCode);

  factory SendResult.authRequired() =>
      const SendResult._(SendOutcome.authRequired, code: "UNAUTHORIZED");
}

/// One outbox push. Injected so [SyncWorker] is fully testable with a fake.
typedef OutboxSender = Future<SendResult> Function(OutboxRow row);

/// Retry/backoff schedule (flutter-plan §3.2):
/// delay = 30s * 4^(attempts-1), capped at 30 min, ±20% jitter.
Duration backoffDelay(int attempts, {math.Random? rng}) {
    final r = rng ?? math.Random();
  final baseSeconds =
      math.min<double>(30 * math.pow(4, math.max(0, attempts - 1)).toDouble(), 1800);
  final jittered = baseSeconds * (0.8 + r.nextDouble() * 0.4);
  return Duration(seconds: jittered.round());
}

int? _seqFromBatchNo(String batchNo) {
  final parts = batchNo.split("-");
  if (parts.length < 3) return null;
  return int.tryParse(parts[2]);
}

/// Push loop for the outbox (WP5). Plain class owned by a Riverpod provider;
/// runs while the app is foregrounded — no background isolate in M1.
///
/// The drain picks the oldest PENDING entry whose `dependsOn` prerequisite has
/// reached SYNCED and whose retry is due, sends it via the injected sender and
/// handles the outcome:
/// - success        → mark entry + entity SYNCED; farms also store the
///                    server-assigned farmer_code (unlocks harvest);
/// - retryable      → attempts++, nextRetryAt = now + backoff(attempts);
/// - batchNoTaken   → regenerate seq/batch_no/payload, rotate idempotency key,
///                    regenCount++ (capped → FAILED_PERMANENT);
/// - permanent      → FAILED_PERMANENT + entity syncState ERROR;
/// - authRequired   → put the entry back to PENDING, pause, raise auth event.
class SyncWorker {
  SyncWorker({
    required AppDatabase db,
    required OutboxSender send,
    OutboxRepository? outbox,
    math.Random? random,
    DateTime Function()? now,
    this.maxRegenerations = 5,
    this.onAuthLost,
  })  : _db = db,
        _sendFn = send,
        _random = random ?? math.Random(),
        _now = now ?? DateTime.now,
        _outbox = outbox ?? OutboxRepository(db);

  final AppDatabase _db;
  final OutboxSender _sendFn;
  final OutboxRepository _outbox;
  final math.Random _random;
  final DateTime Function() _now;

  /// Cap of 409 regenerations per entry before it fails permanently.
  final int maxRegenerations;

  /// Raised when a 401 pauses the drain (router redirects to OTP login;
  /// local data stays untouched).
  void Function()? onAuthLost;

  bool _draining = false;

  /// True while a drain loop is running (single-flight guard).
  bool get isDraining => _draining;

  /// Loop pick→send until the queue is empty or blocked. Concurrent calls are
  /// collapsed into the running drain (single-flight).
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      await _recoverStaleInFlight();
      while (true) {
        final row = await _outbox.pickNextDue(_now());
        if (row == null) return;
        await _outbox.markInFlight(row.id);
        try {
          final result = await _sendFn(row);
          switch (result.outcome) {
            case SendOutcome.success:
              await _handleSuccess(row, result);
              continue; // dependent entries may unblock now
            case SendOutcome.batchNoTaken:
              final regenerated = await _handleBatchNoTaken(row);
              if (!regenerated) {
                await _failPermanent(row, "BATCH_NO_TAKEN");
              }
              continue;
            case SendOutcome.permanent:
              await _failPermanent(row, result.code ?? "REJECTED");
              continue;
            case SendOutcome.retryable:
              // Nothing later in the queue can be due before this row.
              final attempts = row.attempts + 1;
              await _outbox.scheduleRetry(
                row.id,
                attempts: attempts,
                nextRetryAt: _now().add(backoffDelay(attempts, rng: _random)),
                errorCode: result.code ??
                    result.statusCode?.toString() ??
                    "NETWORK",
              );
              return;
            case SendOutcome.authRequired:
              await _outbox.markPending(row.id);
              onAuthLost?.call();
              return;
          }
        } on StateError catch (e) {
          // e.g. SEQ_EXHAUSTED during regeneration — fail this entry only.
          await _failPermanent(row, e.message);
          continue;
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Entries caught mid-flight by an app kill go back to PENDING.
  Future<void> _recoverStaleInFlight() {
    return (_db.update(_db.outbox)
          ..where((t) => t.status.equals(OutboxStatus.inFlight)))
        .write(const OutboxCompanion(status: Value(OutboxStatus.pending)));
  }

  Future<void> _handleSuccess(OutboxRow row, SendResult result) async {
    await _outbox.markSynced(row.id);
    switch (row.entityType) {
      case "farm":
        final farmerCode = result.response?["farmer_code"]?.toString();
        await (_db.update(_db.farms)..where((t) => t.id.equals(row.entityId)))
            .write(
          FarmsCompanion(
            syncState: const Value(SyncStateColumns.synced),
            farmerCode: (farmerCode == null || farmerCode.isEmpty)
                ? const Value.absent()
                : Value(farmerCode),
          ),
        );
      case "batch":
        await (_db.update(_db.batches)..where((t) => t.id.equals(row.entityId)))
            .write(const BatchesCompanion(
          syncState: Value(SyncStateColumns.synced),
        ));
    }
  }

  /// 409 BATCH_NO_TAKEN resolution (flutter-plan §3.2): in ONE transaction
  /// bump the per-farm daily counter past both the stored counter and the
  /// failed number, regenerate the batch number, update the batch row and the
  /// payload, rotate the idempotency key and count the regeneration.
  /// Returns false when the cap is exhausted (caller marks FAILED_PERMANENT).
  Future<bool> _handleBatchNoTaken(OutboxRow row) async {
    if (row.regenCount >= maxRegenerations) return false;
    var regenerated = false;
    await _db.transaction(() async {
      final batch = await _db.batchById(row.entityId);
      if (batch == null) throw StateError("BATCH_NOT_FOUND");
      final farm = await _db.farmById(batch.farmId);
      if (farm == null || farm.farmerCode == null || farm.farmerCode!.isEmpty) {
        throw StateError("FARM_NOT_ACTIVATED");
      }

      final date = DateTime.parse(batch.harvestDate); // yyyy-MM-dd
      final dayKey = "${date.year}-${julianDay(date)}";
      final counter = await (_db.select(_db.seqCounters)
            ..where((t) =>
                t.farmId.equals(batch.farmId) & t.dayKey.equals(dayKey)))
          .getSingleOrNull();
      final failedSeq = _seqFromBatchNo(batch.batchNo) ?? 0;
      final newSeq = math.max(counter?.lastSeq ?? 0, failedSeq) + 1;
      if (newSeq > 99) throw StateError("SEQ_EXHAUSTED");

      await _db.into(_db.seqCounters).insertOnConflictUpdate(
            SeqCountersCompanion.insert(
                farmId: batch.farmId, dayKey: dayKey, lastSeq: newSeq),
          );

      final newBatchNo = generateBatchNo(
        areaCode: farm.areaCode,
        harvestDate: date,
        seq: newSeq,
        farmerCode: farm.farmerCode!,
        type: batch.harvestType == "Q"
            ? HarvestType.quills
            : HarvestType.trees,
      );

      // Number is only immutable after server acceptance — safe to rename
      // while the row is not SYNCED.
      await (_db.update(_db.batches)..where((t) => t.id.equals(batch.id)))
          .write(BatchesCompanion(
        batchNo: Value(newBatchNo),
        rootBatchNo: Value(newBatchNo),
      ));

      final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      payload["batch_no"] = newBatchNo;
      await (_db.update(_db.outbox)..where((t) => t.id.equals(row.id))).write(
        OutboxCompanion(
          payloadJson: Value(jsonEncode(payload)),
          // Payload changed — rotate the key to avoid any server-side
          // idempotency key→response cache ambiguity.
          idempotencyKey: Value(const Uuid().v4()),
          regenCount: Value(row.regenCount + 1),
          status: const Value(OutboxStatus.pending),
          nextRetryAt: Value(_now()),
        ),
      );
      regenerated = true;
    });
    return regenerated;
  }

  Future<void> _failPermanent(OutboxRow row, String code) async {
    await _outbox.markFailedPermanent(row.id, code);
    switch (row.entityType) {
      case "farm":
        await (_db.update(_db.farms)..where((t) => t.id.equals(row.entityId)))
            .write(const FarmsCompanion(
          syncState: Value(SyncStateColumns.error),
        ));
      case "batch":
        await (_db.update(_db.batches)..where((t) => t.id.equals(row.entityId)))
            .write(const BatchesCompanion(
          syncState: Value(SyncStateColumns.error),
        ));
    }
  }
}

// ---- Riverpod wiring --------------------------------------------------------

/// Production sender: POST the queued path with the Idempotency-Key header and
/// the exact stored JSON body, mapping ApiClient errors onto [SendOutcome].
Future<SendResult> apiOutboxSender(ApiClient api, OutboxRow row) async {
  try {
    final res = await api.post(
      row.path,
      body: jsonDecode(row.payloadJson),
      headers: {"Idempotency-Key": row.idempotencyKey},
    );
    return SendResult.success(
        res is Map ? Map<String, dynamic>.from(res) : null);
  } on ApiException catch (e) {
    if (e.status == 401) return SendResult.authRequired();
    if (e.status == 409 && e.code == "BATCH_NO_TAKEN") {
      return SendResult.batchNoTaken();
    }
    if (e.status == null || (e.status != null && e.status! >= 500)) {
      // NETWORK / TIMEOUT / server fault — transient.
      return SendResult.retryable(code: e.code, statusCode: e.status);
    }
    return SendResult.permanent(e.code, statusCode: e.status);
  }
}

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final api = ref.watch(apiClientProvider);
  final worker = SyncWorker(
    db: ref.watch(appDatabaseProvider),
    send: (row) => apiOutboxSender(api, row),
    onAuthLost: () => ref.read(authProvider.notifier).sessionExpired(),
  );
  ref.onDispose(() => worker.onAuthLost = null);
  return worker;
});

/// Number of outbox entries still waiting to leave the device — drives the
/// Home "waiting to sync" banner and manual "Sync now".
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(outboxRepoProvider).watchPendingCount();
});

/// Activates the sync triggers once at app start (WP5):
/// app start, connectivity regained, after re-login. Enqueue-time and manual
/// "Sync now" triggers are fired by their call sites.
final syncBootstrapProvider = Provider<void>((ref) {
  final worker = ref.watch(syncWorkerProvider);

  StreamSubscription<List<ConnectivityResult>>? connectivitySub;
  ProviderSubscription<AuthState>? authSub;

  void kick() {
    unawaited(worker.drain());
  }

  // App start / after auth restored / after re-login (drain resumes).
  authSub = ref.listen<AuthState>(authProvider, (_, next) {
    if (next is SignedIn) kick();
  });
  if (ref.read(authProvider) is SignedIn) kick();

  // Connectivity regained.
  connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) kick();
  });

  ref.onDispose(() {
    connectivitySub?.cancel();
    authSub?.close();
  });
});

import "dart:async";

import "package:drift/drift.dart";

import "../db/app_database.dart";
import "../db/tables.dart";

/// Low-level outbox operations shared by the write-path repositories and the
/// [SyncWorker] (flutter-plan §3.2).
class OutboxRepository {
  OutboxRepository(this._db);

  final AppDatabase _db;

  /// Appends a PENDING entry. Returns its outbox id.
  Future<int> enqueue({
    required String entityType,
    required String entityId,
    required String method,
    required String path,
    required String payloadJson,
    required String idempotencyKey,
    int? dependsOn,
  }) {
    return _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            method: method,
            path: path,
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            dependsOn: Value(dependsOn),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Dependency-aware pick query (flutter-plan §3.2): oldest PENDING entry
  /// whose retry is due and whose prerequisite (if any) has reached SYNCED.
  Future<OutboxRow?> pickNextDue(DateTime now) {
    final syncedIds = _db.selectOnly(_db.outbox)
      ..addColumns([_db.outbox.id])
      ..where(_db.outbox.status.equals(OutboxStatus.synced));

    return (_db.select(_db.outbox)
          ..where(
            (t) =>
                t.status.equals(OutboxStatus.pending) &
                (t.nextRetryAt.isNull() |
                    t.nextRetryAt.isSmallerOrEqualValue(now)) &
                (t.dependsOn.isNull() | t.dependsOn.isInQuery(syncedIds)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> markInFlight(int id) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id)))
        .write(const OutboxCompanion(status: Value(OutboxStatus.inFlight)));
  }

  Future<void> markPending(int id, {DateTime? nextRetryAt}) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: const Value(OutboxStatus.pending),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  Future<void> markSynced(int id) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      const OutboxCompanion(
        status: Value(OutboxStatus.synced),
        lastErrorCode: Value(null),
      ),
    );
  }

  Future<void> markFailedPermanent(int id, String errorCode) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: const Value(OutboxStatus.failedPermanent),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  Future<void> scheduleRetry(
    int id, {
    required int attempts,
    required DateTime nextRetryAt,
    String? errorCode,
  }) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        attempts: Value(attempts),
        nextRetryAt: Value(nextRetryAt),
        status: const Value(OutboxStatus.pending),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  /// Number of entries still waiting to be pushed (any non-SYNCED state).
  Stream<int> watchPendingCount() {
    final count = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([count])
      ..where(
        _db.outbox.status.isNotIn([
          OutboxStatus.synced,
          OutboxStatus.failedPermanent,
        ]),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<int> pendingCount() async {
    final count = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([count])
      ..where(
        _db.outbox.status.isNotIn([
          OutboxStatus.synced,
          OutboxStatus.failedPermanent,
        ]),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Newest outbox entry for an entity that has not reached SYNCED yet —
  /// used to wire up `dependsOn` ordering between farms and their batches.
  Future<OutboxRow?> unsyncedEntryFor(String entityId) {
    return (_db.select(_db.outbox)
          ..where(
            (t) =>
                t.entityId.equals(entityId) &
                t.status.isNotIn([OutboxStatus.synced]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }
}

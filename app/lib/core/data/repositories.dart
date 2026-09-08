import "dart:async";
import "dart:convert";

import "package:drift/drift.dart" hide Batch;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../api/api_client.dart";
import "../api/api_exception.dart";
import "../auth/auth_state.dart";
import "../db/app_database.dart";
import "../db/tables.dart";
import "../domain/batch_number_generator.dart";
import "../sync/outbox_repository.dart";

/// Data layer for farms and batches (WP2).
///
/// Repositories are the ONLY write path for these entities: every mutation is
/// a local drift transaction that stores the row with `syncState = LOCAL` and
/// appends an outbox entry; the [SyncWorker] pushes it later. Screens never
/// call [ApiClient] for farms/batches writes.
///
/// Pull methods upsert server rows with two rules: server wins over SYNCED
/// local rows, and LOCAL rows still queued in the outbox are never clobbered.

/// Batch statuses in which the current holder may transfer onward — mirrors
/// TRANSFERABLE_STATUSES on the server.
const transferableStatuses = {"HARVESTED", "RECEIVED", "PROCESSED"};

final outboxRepoProvider =
    Provider<OutboxRepository>((ref) => OutboxRepository(ref.watch(appDatabaseProvider)));

final farmsRepoProvider = Provider<FarmsRepository>(
  (ref) => FarmsRepository(ref.watch(appDatabaseProvider), ref.watch(outboxRepoProvider),
      api: ref.watch(apiClientProvider)),
);

final batchesRepoProvider = Provider<BatchesRepository>(
  (ref) => BatchesRepository(ref.watch(appDatabaseProvider), ref.watch(outboxRepoProvider),
      api: ref.watch(apiClientProvider)),
);

/// Farms, watched from the local drift DB (offline-first).
final farmsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(farmsRepoProvider).watchFarmsAsMaps();
});

/// Batches, watched from the local drift DB (offline-first).
final batchesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(batchesRepoProvider).watchBatchesAsMaps();
});

/// Local-first single batch: emits the cached drift row immediately, then
/// refreshes from `GET /batches/{id}` when online (chain, origin, status).
/// If the row is only on the server it appears once the refresh lands; if the
/// device is offline and nothing is cached, the provider errors.
final batchByIdProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(batchesRepoProvider).watchBatchById(id);
});

// ----------------------------------------------------------------------------

class FarmsRepository {
  FarmsRepository(this._db, this._outbox, {required this.api});

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final ApiClient api;
  final Uuid _uuid = const Uuid();

  Stream<List<Farm>> watchFarms() {
    return (_db.select(_db.farms)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<Map<String, dynamic>>> watchFarmsAsMaps() {
    return watchFarms().map((rows) => [for (final r in rows) farmToMap(r)]);
  }

  /// Inserts a farm row (syncState LOCAL) and enqueues `POST /farms` in ONE
  /// transaction. Returns the local UUIDv7 id.
  Future<String> saveFarmDraft({
    required String name,
    required String areaCode,
    required double sizeValue,
    String sizeUnit = "ACRE",
    double? lat,
    double? lng,
    String? addressText,
    String locationPublicLevel = "DISTRICT",
  }) async {
    final id = _uuid.v7();
    await _db.transaction(() async {
      await _db.into(_db.farms).insert(
            FarmsCompanion.insert(
              id: id,
              name: name,
              areaCode: areaCode,
              sizeValue: sizeValue,
              sizeUnit: Value(sizeUnit),
              lat: Value(lat),
              lng: Value(lng),
              addressText: Value(addressText),
              locationPublicLevel: Value(locationPublicLevel),
              createdAt: DateTime.now(),
            ),
          );
      await _outbox.enqueue(
        entityType: "farm",
        entityId: id,
        method: "POST",
        path: "/farms",
        payloadJson: jsonEncode({
          "id": id,
          "name": name,
          "area_code": areaCode,
          "size_value": sizeValue,
          "size_unit": sizeUnit,
          "lat": lat,
          "lng": lng,
          "address_text": addressText,
          "location_public_level": locationPublicLevel,
        }),
        idempotencyKey: _uuid.v4(),
      );
    });
    return id;
  }

  /// `GET /farms` → upsert. Server wins over SYNCED; never over LOCAL rows
  /// whose outbox entry is still pending. Reconciles deleted server rows.
  Future<void> pullFarms() async {
    final data = await api.get("/farms");
    final list = data as List? ?? const [];
    final serverIds = <String>{};
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m["id"].toString();
      serverIds.add(id);
      await _upsertFarmFromServer(m);
    }
    // Reconcile: delete local synced rows that no longer exist on the server
    await (_db.delete(_db.farms)
          ..where((t) =>
              t.syncState.equals(SyncStateColumns.synced) &
              t.id.isNotIn(serverIds)))
        .go();
  }

  Future<void> _upsertFarmFromServer(Map<String, dynamic> json) async {
    final id = json["id"].toString();
    final existing = await _db.farmById(id);
    if (existing != null && existing.syncState == SyncStateColumns.local) {
      return; // local row still queued in the outbox — server must not win
    }
    final row = FarmsCompanion.insert(
      id: id,
      name: json["name"]?.toString() ?? "",
      areaCode: json["area_code"]?.toString() ?? "",
      farmerCode: Value(_stringOrNull(json["farmer_code"])),
      sizeValue: (num.tryParse("${json["size_value"]}") ?? 0).toDouble(),
      sizeUnit: Value(json["size_unit"]?.toString() ?? "ACRE"),
      lat: Value(_doubleOrNull(json["lat"])),
      lng: Value(_doubleOrNull(json["lng"])),
      addressText: Value(_stringOrNull(json["address_text"])),
      locationPublicLevel:
          Value(json["location_public_level"]?.toString() ?? "DISTRICT"),
      syncState: const Value(SyncStateColumns.synced),
      createdAt: _dateOrNull(json["created_at"]) ?? DateTime.now(),
    );
    await _db.into(_db.farms).insertOnConflictUpdate(row);
  }

  /// Marks a farm synced after its outbox entry succeeded; [farmerCode] from
  /// the POST /farms response is what unlocks harvests for this farm.
  Future<void> markFarmSynced(String id, {String? farmerCode}) {
    return (_db.update(_db.farms)..where((t) => t.id.equals(id))).write(
      FarmsCompanion(
        syncState: const Value(SyncStateColumns.synced),
        farmerCode: (farmerCode == null || farmerCode.isEmpty)
            ? const Value.absent()
            : Value(farmerCode),
      ),
    );
  }

  Future<void> markFarmError(String id) {
    return (_db.update(_db.farms)..where((t) => t.id.equals(id))).write(
      const FarmsCompanion(syncState: Value(SyncStateColumns.error)),
    );
  }
}

// ----------------------------------------------------------------------------

class BatchesRepository {
  BatchesRepository(this._db, this._outbox, {required this.api});

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final ApiClient api;
  final Uuid _uuid = const Uuid();

  Stream<List<Batch>> watchBatches() {
    return (_db.select(_db.batches)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Map<String, dynamic>>> watchBatchesAsMaps() {
    return watchBatches().map((rows) => [for (final r in rows) batchToMap(r)]);
  }

  /// One drift transaction (flutter-plan §4.4): allocate SEQ from
  /// SeqCounters(farmId, dayKey), generate the batch number, insert the batch
  /// row (HARVESTED, holder = self, rootBatchNo = batchNo) and enqueue the
  /// outbox entry — `dependsOn` the farm's outbox entry while it isn't SYNCED.
  /// Returns the local batch row id.
  Future<String> saveHarvest({
    required String farmId,
    required String holderId,
    required DateTime harvestDate,
    required HarvestType type,
    required int treeCount,
    required double weightKg,
  }) {
    return _db.transaction(() async {
      final farm = await _db.farmById(farmId);
      if (farm == null) {
        throw StateError("FARM_NOT_FOUND");
      }
      if (farm.farmerCode == null || farm.farmerCode!.isEmpty) {
        // Server assigns farmer_code on farm creation — no harvest until then.
        throw StateError("FARM_NOT_ACTIVATED");
      }

      final dayKey = "${harvestDate.year}-${julianDay(harvestDate)}";
      final counter = await (_db.select(_db.seqCounters)
            ..where((t) =>
                t.farmId.equals(farmId) & t.dayKey.equals(dayKey)))
          .getSingleOrNull();
      final seq = (counter?.lastSeq ?? 0) + 1;
      if (seq > 99) {
        throw StateError("SEQ_EXHAUSTED");
      }

      await _db.into(_db.seqCounters).insertOnConflictUpdate(
            SeqCountersCompanion.insert(
                farmId: farmId, dayKey: dayKey, lastSeq: seq),
          );

      final batchNo = generateBatchNo(
        areaCode: farm.areaCode,
        harvestDate: harvestDate,
        seq: seq,
        farmerCode: farm.farmerCode!,
        type: type,
      );

      final id = _uuid.v7();
      final harvestDateText =
          "${harvestDate.year.toString().padLeft(4, "0")}-${harvestDate.month.toString().padLeft(2, "0")}-${harvestDate.day.toString().padLeft(2, "0")}";

      await _db.into(_db.batches).insert(
            BatchesCompanion.insert(
              id: id,
              batchNo: batchNo,
              farmId: farmId,
              harvestType: type.code,
              harvestDate: harvestDateText,
              treeCount: treeCount,
              weightKg: weightKg,
              rootBatchNo: batchNo,
              currentHolderId: Value(holderId),
              currentHolderRole: const Value("FARMER"),
              createdAt: DateTime.now(),
            ),
          );

      final payload = jsonEncode({
        "id": id,
        "farm_id": farmId,
        "batch_no": batchNo,
        "harvest_type": type.code,
        "harvest_date": harvestDateText,
        "tree_count": treeCount,
        "weight_kg": weightKg,
      });

      // A batch whose farm entry is still queued cannot sync first — the
      // server would reject a batch referencing an unknown farm.
      final farmEntry = await _outbox.unsyncedEntryFor(farmId);
      await _outbox.enqueue(
        entityType: "batch",
        entityId: id,
        method: "POST",
        path: "/batches",
        payloadJson: payload,
        idempotencyKey: _uuid.v4(),
        dependsOn: farmEntry?.id,
      );

      return id;
    });
  }

  /// `GET /batches` → upsert. Server wins over SYNCED; never over LOCAL rows
  /// whose outbox entry is still pending. Reconciles deleted server rows.
  Future<void> pullBatches() async {
    final data = await api.get("/batches", query: {"limit": 100});
    final list = (data as Map?)?["data"] as List? ?? const [];
    final serverIds = <String>{};
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m["id"].toString();
      serverIds.add(id);
      await _upsertBatchFromServer(m);
    }
    // Reconcile: delete local synced rows that no longer exist on the server
    await (_db.delete(_db.batches)
          ..where((t) =>
              t.syncState.equals(SyncStateColumns.synced) &
              t.id.isNotIn(serverIds)))
        .go();
  }

  Future<void> _upsertBatchFromServer(Map<String, dynamic> json) async {
    final id = json["id"].toString();
    final existing = await _db.batchById(id);
    if (existing != null && existing.syncState == SyncStateColumns.local) {
      final serverStatus = json["status"]?.toString();
      final serverHolder = _stringOrNull(json["current_holder_id"]);
      if (serverStatus != null &&
          (serverStatus != "HARVESTED" || serverHolder != existing.currentHolderId)) {
        // Server already has downstream custody/status change; accept server truth.
      } else {
        return; // still locally pending creation outbox
      }
    }
    try {
      await _db.into(_db.batches).insertOnConflictUpdate(_batchRow(json));
    } catch (_) {
      // Unique(batchNo) conflict against a LOCAL row (same number generated on
      // another device) — the 409 regen path will resolve it after sync; skip.
    }
  }

  /// Immediately updates a batch in local drift DB when transferred/sold, so the UI
  /// locks the batch for the sender without waiting for outbox or pullBatches.
  Future<void> updateBatchLocalTransfer({
    required String batchId,
    required String toUserId,
    required String? toRole,
  }) async {
    await (_db.update(_db.batches)..where((t) => t.id.equals(batchId))).write(
      BatchesCompanion(
        status: const Value("IN_TRANSIT"),
        currentHolderId: Value(toUserId),
        currentHolderRole: Value(toRole),
        syncState: const Value(SyncStateColumns.synced),
      ),
    );
  }

  /// Immediately updates a batch in local drift DB when accepted, so the UI
  /// unlocks the batch and reflects custody without waiting for network pullBatches.
  Future<void> updateBatchLocalAccept({
    required String batchId,
    required String holderId,
    required String? holderRole,
  }) async {
    await (_db.update(_db.batches)..where((t) => t.id.equals(batchId))).write(
      BatchesCompanion(
        status: const Value("RECEIVED"),
        currentHolderId: Value(holderId),
        currentHolderRole: Value(holderRole),
        syncState: const Value(SyncStateColumns.synced),
      ),
    );
  }

  BatchesCompanion _batchRow(Map<String, dynamic> json) {
    return BatchesCompanion.insert(
      id: json["id"].toString(),
      batchNo: json["batch_no"]?.toString() ?? "",
      farmId: json["farm_id"]?.toString() ?? "",
      harvestType: json["harvest_type"]?.toString() ?? "T",
      harvestDate: json["harvest_date"]?.toString() ?? "",
      treeCount: int.tryParse("${json["tree_count"]}") ?? 0,
      weightKg: (num.tryParse("${json["weight_kg"]}") ?? 0).toDouble(),
      status: Value(json["status"]?.toString() ?? "HARVESTED"),
      currentHolderId: Value(_stringOrNull(json["current_holder_id"])),
      currentHolderRole: Value(_stringOrNull(json["current_holder_role"])),
      rootBatchNo: json["root_batch_no"]?.toString() ??
          json["batch_no"]?.toString() ??
          "",
      stageSuffix: Value(json["stage_suffix"]?.toString() ?? ""),
      syncState: const Value(SyncStateColumns.synced),
      createdAt: _dateOrNull(json["created_at"]) ?? DateTime.now(),
    );
  }

  /// Local-first single-batch stream: emits the cached row immediately (and
  /// on every drift change, e.g. a 409 regen renaming the batch number), then
  /// refreshes from the API when online and yields the richer server view
  /// (chain, origin). Offline with no cached row → error.
  Stream<Map<String, dynamic>> watchBatchById(String id) async* {
    Map<String, dynamic>? serverView;
    var refreshSettled = false;
    Object? refreshError;

    Future<void> doRefresh() async {
      try {
        final data = await api.get("/batches/$id");
        final m = Map<String, dynamic>.from(data as Map);
        // Cache core fields for offline use, but never clobber LOCAL rows
        // still queued in the outbox.
        await _upsertBatchFromServer(m);
        serverView = m;
      } catch (e) {
        refreshError = e;
        if (e is ApiException && e.status == 404) {
          // If server reports 404, clean up local stale synced row
          final local = await _db.batchById(id);
          if (local != null && local.syncState == SyncStateColumns.synced) {
            await (_db.delete(_db.batches)..where((t) => t.id.equals(id))).go();
          }
        }
      } finally {
        refreshSettled = true;
      }
    }

    final refreshFuture = doRefresh();
    final localStream = (_db.select(_db.batches)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();

    await for (final row in localStream) {
      if (row != null) {
        // Local-first: cached row goes out immediately.
        // If serverView is present, merge latest local row status and custody
        // so that local accept/transfer events immediately update the view.
        if (serverView != null) {
          final merged = Map<String, dynamic>.from(serverView!);
          merged["status"] = row.status;
          merged["current_holder_id"] = row.currentHolderId;
          merged["current_holder_role"] = row.currentHolderRole;
          yield merged;
        } else {
          yield batchToMap(row);
        }
      }
      if (!refreshSettled) {
        await refreshFuture;
        if (serverView != null) {
          final merged = Map<String, dynamic>.from(serverView!);
          if (row != null) {
            merged["status"] = row.status;
            merged["current_holder_id"] = row.currentHolderId;
            merged["current_holder_role"] = row.currentHolderRole;
          }
          yield merged;
        } else if (row == null) {
          throw refreshError ??
              ApiException(
                code: "NOT_FOUND",
                message: "Batch not found on this device",
                status: 404,
              );
        }
        // row != null && refresh failed → keep showing the cached row.
      } else if (row == null && serverView != null) {
        yield serverView!;
      }
    }
  }

  /// Marks a batch synced after its outbox entry succeeded.
  Future<void> markBatchSynced(String id) {
    return (_db.update(_db.batches)..where((t) => t.id.equals(id))).write(
      const BatchesCompanion(syncState: Value(SyncStateColumns.synced)),
    );
  }

  Future<void> markBatchError(String id) {
    return (_db.update(_db.batches)..where((t) => t.id.equals(id))).write(
      const BatchesCompanion(syncState: Value(SyncStateColumns.error)),
    );
  }
}

// ----------------------------------------------------------------------------

Map<String, dynamic> farmToMap(Farm f) => {
      "id": f.id,
      "name": f.name,
      "area_code": f.areaCode,
      "farmer_code": f.farmerCode,
      "size_value": f.sizeValue,
      "size_unit": f.sizeUnit,
      "lat": f.lat,
      "lng": f.lng,
      "address_text": f.addressText,
      "location_public_level": f.locationPublicLevel,
      "sync_state": f.syncState,
      "created_at": f.createdAt.toIso8601String(),
    };

Map<String, dynamic> batchToMap(Batch b) => {
      "id": b.id,
      "batch_no": b.batchNo,
      "farm_id": b.farmId,
      "harvest_type": b.harvestType,
      "harvest_date": b.harvestDate,
      "tree_count": b.treeCount,
      "weight_kg": b.weightKg,
      "status": b.status,
      "current_holder_id": b.currentHolderId,
      "current_holder_role": b.currentHolderRole,
      "root_batch_no": b.rootBatchNo,
      "stage_suffix": b.stageSuffix,
      "sync_state": b.syncState,
      "created_at": b.createdAt.toIso8601String(),
    };

String? _stringOrNull(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

double? _doubleOrNull(dynamic v) =>
    v == null ? null : num.tryParse("$v")?.toDouble();

DateTime? _dateOrNull(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

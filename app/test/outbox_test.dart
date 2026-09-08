import "dart:math";

import "package:drift/drift.dart" hide Batch, isNotNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

import "package:cinnamon_trace/core/api/api_client.dart";
import "package:cinnamon_trace/core/data/repositories.dart";
import "package:cinnamon_trace/core/db/app_database.dart";
import "package:cinnamon_trace/core/db/tables.dart";
import "package:cinnamon_trace/core/domain/batch_number_generator.dart";
import "package:cinnamon_trace/core/sync/outbox_repository.dart";
import "package:cinnamon_trace/core/sync/sync_worker.dart";

void main() {

  late AppDatabase db;
  late OutboxRepository outbox;
  late FarmsRepository farms;
  late BatchesRepository batches;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    // Constructing ApiClient is offline-safe (dio connects lazily); these
    // tests never touch pull paths — sends go through the injected fake.
    farms = FarmsRepository(db, outbox, api: ApiClient());
    batches = BatchesRepository(db, outbox, api: ApiClient());
  });

  tearDown(() async => db.close());

  /// Creates an ACTIVATED farm (syncState SYNCED + farmer_code A) with no
  /// pending outbox entry, so tests can enqueue just a batch.
  Future<String> activatedFarm() async {
    final id = await farms.saveFarmDraft(
      name: "Home Garden",
      areaCode: "GM",
      sizeValue: 1.5,
    );
    await farms.markFarmSynced(id, farmerCode: "A");
    final entry = await outbox.unsyncedEntryFor(id);
    if (entry != null) await outbox.markSynced(entry.id);
    return id;
  }

  group("outbox sync engine", () {
    test("harvest is refused until the farm has a server-assigned farmer_code",
        () async {
      // Fresh offline farm: no farmer_code yet — harvest must be impossible.
      final farmId = await farms.saveFarmDraft(
        name: "Home Garden",
        areaCode: "GM",
        sizeValue: 1.5,
      );
      expect(
        () => batches.saveHarvest(
          farmId: farmId,
          holderId: "user-1",
          harvestDate: DateTime(2026, 8, 17),
          type: HarvestType.trees,
          treeCount: 45,
          weightKg: 120.5,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          "message",
          "FARM_NOT_ACTIVATED",
        )),
      );
    });
    test("farm syncs before its dependent batch; farmer_code unlocks the farm",
        () async {
      // Farm row carries a farmer_code (e.g. pulled from another device) but
      // its own outbox entry is STILL PENDING — the exact case where the
      // batch's dependsOn wiring matters.
      final farmId = await farms.saveFarmDraft(
        name: "Home Garden",
        areaCode: "GM",
        sizeValue: 1.5,
      );
      await farms.markFarmSynced(farmId, farmerCode: "A");
      final farmEntry = await outbox.unsyncedEntryFor(farmId);
      expect(farmEntry, isNotNull);

      final batchId = await batches.saveHarvest(
        farmId: farmId,
        holderId: "user-1",
        harvestDate: DateTime(2026, 8, 17),
        type: HarvestType.trees,
        treeCount: 45,
        weightKg: 120.5,
      );

      final order = <String>[];
      final worker = SyncWorker(
        db: db,
        send: (row) async {
          order.add(row.path);
          if (row.path == "/farms") {
            return SendResult.success({"farmer_code": "A"});
          }
          return SendResult.success();
        },
      );
      await worker.drain();

      expect(order, ["/farms", "/batches"],
          reason: "a batch must never reach the server before its farm");

      final farm = await db.farmById(farmId);
      expect(farm!.syncState, SyncStateColumns.synced);
      expect(farm.farmerCode, "A");

      final batch = await db.batchById(batchId);
      expect(batch!.syncState, SyncStateColumns.synced);
      expect(batch.batchNo, startsWith("GM-"));
      expect(isValidBatchNo(batch.batchNo), isTrue);

      expect(await outbox.pendingCount(), 0);
    });

    test("backoff grows ~4x per attempt, capped at 30 min, ±20% jitter",
        () async {
      Duration d(int attempts) => backoffDelay(attempts, rng: Random(7));

      for (final attempts in [1, 2, 3]) {
        final base = 30.0 * pow(4, attempts - 1);
        final seconds = d(attempts).inSeconds.toDouble();
        expect(seconds, inInclusiveRange(base * 0.8, base * 1.2),
            reason: "attempts=$attempts → ${seconds}s");
      }
      // Cap: base is clamped to 1800s regardless of attempt count.
      final capped = d(12).inSeconds.toDouble();
      expect(capped, inInclusiveRange(1800 * 0.8, 1800 * 1.2));
    });

    test(
        "409 BATCH_NO_TAKEN regenerates seq+1, rotates the idempotency key and bumps the counter",
        () async {
      final farmId = await activatedFarm();
      final batchId = await batches.saveHarvest(
        farmId: farmId,
        holderId: "user-1",
        harvestDate: DateTime(2026, 8, 17),
        type: HarvestType.trees,
        treeCount: 45,
        weightKg: 120.5,
      );
      final originalNo = (await db.batchById(batchId))!.batchNo;
      expect(originalNo, contains("-01-"));

      var calls = 0;
      String? firstKey;
      final worker = SyncWorker(
        db: db,
        random: Random(3),
        send: (row) async {
          calls++;
          firstKey ??= row.idempotencyKey;
          // First attempt collides, the regenerated number goes through.
          if (calls == 1) return SendResult.batchNoTaken();
          return SendResult.success();
        },
      );
      await worker.drain();

      final batch = (await db.batchById(batchId))!;
      expect(batch.syncState, SyncStateColumns.synced);
      // Seq bumped from 01 to 02, same day/farm/type segments preserved.
      expect(batch.batchNo, contains("-02-"));
      expect(batch.rootBatchNo, batch.batchNo);

      // Daily counter advanced past the failed number.
      final counter = await (db.select(db.seqCounters)
            ..where((t) =>
                t.farmId.equals(farmId) & t.dayKey.equals("2026-229")))
          .getSingleOrNull();
      expect(counter!.lastSeq, 2); // Aug 17 2026 is Julian day 229

      // Payload rewritten and idempotency key rotated exactly once.
      final row = await (db.select(db.outbox)
            ..where((t) => t.entityId.equals(batchId)))
          .getSingle();
      expect(row.payloadJson, contains("-02-"));
      expect(row.idempotencyKey, isNot(firstKey));
      expect(row.regenCount, 1);
      expect(calls, 2);
    });

    test("regeneration cap exhausted → FAILED_PERMANENT + batch ERROR",
        () async {
      final farmId = await activatedFarm();
      await batches.saveHarvest(
        farmId: farmId,
        holderId: "user-1",
        harvestDate: DateTime(2026, 8, 17),
        type: HarvestType.quills,
        treeCount: 10,
        weightKg: 40,
      );

      final worker = SyncWorker(
        db: db,
        random: Random(1),
        maxRegenerations: 2,
        send: (_) async => SendResult.batchNoTaken(), // never resolves
      );
      await worker.drain();

      final row = await (db.select(db.outbox)
            ..where((t) => t.entityType.equals("batch")))
          .getSingle();
      expect(row.status, OutboxStatus.failedPermanent);
      expect(row.regenCount, 2);
      expect(row.lastErrorCode, "BATCH_NO_TAKEN");

      final batch = await db.batchById(row.entityId);
      expect(batch!.syncState, SyncStateColumns.error);
    });

    test("auth loss pauses the drain and keeps the entry PENDING", () async {
      final farmId = await activatedFarm();
      await batches.saveHarvest(
        farmId: farmId,
        holderId: "user-1",
        harvestDate: DateTime(2026, 8, 17),
        type: HarvestType.trees,
        treeCount: 5,
        weightKg: 20,
      );

      var authLost = false;
      final worker = SyncWorker(
        db: db,
        send: (_) async => SendResult.authRequired(),
      )..onAuthLost = () => authLost = true;

      await worker.drain();

      expect(authLost, isTrue);
      expect(await outbox.pendingCount(), 1); // still queued, nothing lost
    });

    test("concurrent drains collapse into one loop (single-flight)", () async {
      final farmId = await activatedFarm();
      for (var i = 0; i < 2; i++) {
        await batches.saveHarvest(
          farmId: farmId,
          holderId: "user-1",
          harvestDate: DateTime(2026, 8, 17),
          type: HarvestType.trees,
          treeCount: i + 1,
          weightKg: 5.0 * (i + 1),
        );
      }

      var inFlight = 0;
      var maxInFlight = 0;
      final worker = SyncWorker(
        db: db,
        send: (row) async {
          inFlight++;
          maxInFlight = max(maxInFlight, inFlight);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
          return SendResult.success();
        },
      );

      // Fire two drains without awaiting the first — they must collapse.
      final f1 = worker.drain();
      final f2 = worker.drain();
      await Future.wait([f1, f2]);

      expect(maxInFlight, 1);
      expect(worker.isDraining, isFalse);
      expect(await outbox.pendingCount(), 0);
    });
  });
}

import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "tables.dart";

part "app_database.g.dart";

/// Single shared database instance for the whole app (one connection, one
/// cache). Lives here — a leaf module — so auth, repositories and sync can
/// all depend on it without import cycles.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// drift database for the offline-first layer.
///
/// The connection is created via drift_flutter's [driftDatabase] helper so the
/// SAME code runs native (sqlite3 through sqlite3_flutter_libs) and web
/// (WasmDatabase loading web/sqlite3.wasm + web/drift_worker.js).
///
/// Tests inject an executor directly: `AppDatabase(NativeDatabase.memory())`.
/// The DB opens lazily on first use (never blocks app startup).
@DriftDatabase(tables: [Farms, Batches, SeqCounters, Outbox, MetaKv])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production constructor.
  AppDatabase.open() : super(driftDatabase(name: "cinnamon_trace"));

  @override
  int get schemaVersion => 1;

  // ---- MetaKv helpers -------------------------------------------------------

  Future<String?> getMeta(String key) async {
    final row =
        await (select(metaKv)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    await into(metaKv).insertOnConflictUpdate(
      MetaKvCompanion.insert(key: key, value: value),
    );
  }

  Future<void> removeMeta(String key) async {
    await (delete(metaKv)..where((t) => t.key.equals(key))).go();
  }

  // ---- Batch helpers --------------------------------------------------------

  Future<Batch?> batchById(String id) async {
    return (select(batches)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Farm?> farmById(String id) async {
    return (select(farms)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Clears all synced records and sequence counters on logout / user switch,
  /// ensuring deleted data on backend or past accounts never leak across sessions.
  Future<void> purgeSyncedData() async {
    await transaction(() async {
      await (delete(farms)..where((t) => t.syncState.equals(SyncStateColumns.synced))).go();
      await (delete(batches)..where((t) => t.syncState.equals(SyncStateColumns.synced))).go();
      await delete(seqCounters).go();
    });
  }
}

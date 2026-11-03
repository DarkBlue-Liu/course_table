import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/database/app_database.dart';
import '../../domain/models/time_slot.dart';
import '../time_slot_repository.dart';
import 'mappers.dart';

/// 本地实现：节次表整表替换（事务内先删后插），保证 slot_index 唯一。
class LocalTimeSlotRepository implements TimeSlotRepository {
  LocalTimeSlotRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<TimeSlot>> getAll() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableTimeSlot,
      orderBy: DbConstants.colSlotIndex,
    );
    return rows.map(Mappers.timeSlotFromRow).toList();
  }

  @override
  Future<void> replaceAll(List<TimeSlot> slots) async {
    final Database db = await _appDatabase.database;
    await db.transaction<void>((Transaction txn) async {
      await txn.delete(DbConstants.tableTimeSlot);
      final Batch batch = txn.batch();
      for (final TimeSlot slot in slots) {
        batch.insert(
          DbConstants.tableTimeSlot,
          Mappers.timeSlotToRow(slot, includeId: false),
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> updateSlot(TimeSlot slot) async {
    final Database db = await _appDatabase.database;
    if (slot.id == null) {
      await db.insert(
        DbConstants.tableTimeSlot,
        Mappers.timeSlotToRow(slot, includeId: false),
      );
      return;
    }
    await db.update(
      DbConstants.tableTimeSlot,
      Mappers.timeSlotToRow(slot),
      where: '${DbConstants.colId} = ?',
      whereArgs: <Object?>[slot.id],
    );
  }
}

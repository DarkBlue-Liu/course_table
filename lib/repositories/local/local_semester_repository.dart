import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/database/app_database.dart';
import '../../domain/models/semester.dart';
import '../semester_repository.dart';
import 'mappers.dart';

/// 本地实现：单行表，id 固定为 1，用 REPLACE 覆盖写入。
class LocalSemesterRepository implements SemesterRepository {
  LocalSemesterRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<Semester?> getSemester() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableSemester,
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Mappers.semesterFromRow(rows.first);
  }

  @override
  Future<void> saveSemester(Semester semester) async {
    final Database db = await _appDatabase.database;
    await db.insert(
      DbConstants.tableSemester,
      Mappers.semesterToRow(semester),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import '../utils/logger.dart';
import 'db_seed.dart';

/// 数据库入口：打开、建表、版本迁移、外键开关。
/// 单例使用；测试时可注入 [factory] 与 [pathOverride]（配合 sqflite_common_ffi）。
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? pathOverride})
      : _factory = factory,
        _pathOverride = pathOverride;

  final DatabaseFactory? _factory;
  final String? _pathOverride;

  Database? _db;

  DatabaseFactory get _resolvedFactory => _factory ?? databaseFactory;

  Future<Database> get database async {
    final Database? existing = _db;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    return _db = await _open();
  }

  Future<Database> _open() async {
    final DatabaseFactory factory = _resolvedFactory;
    final String path = _pathOverride ??
        p.join(await factory.getDatabasesPath(), DbConstants.databaseName);
    Logger.debug('打开数据库: $path');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DbConstants.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: onDatabaseDowngradeDelete,
      ),
    );
  }

  /// sqflite 默认关闭外键，必须显式打开，否则级联删除不生效。
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    Logger.debug('建表 v$version');
    final Batch batch = db.batch();
    for (final String sql in DbConstants.createStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
    await DbSeed.insertDefaultTimeSlots(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.debug('迁移数据库 $oldVersion -> $newVersion');
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE ${DbConstants.tableSemester} ADD COLUMN ${DbConstants.colStartDate} TEXT');
      await db.execute(
          'ALTER TABLE ${DbConstants.tableSemester} ADD COLUMN ${DbConstants.colHolidayStartDate} TEXT');
      await db.execute(
          'ALTER TABLE ${DbConstants.tableSemester} ADD COLUMN ${DbConstants.colAutoWeeks} INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

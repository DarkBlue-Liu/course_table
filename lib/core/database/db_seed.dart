import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';

/// 首次安装时预置的节次时间表（用户可在设置中修改）。
/// 时间一律用「一天中的分钟数」表示。
class DbSeed {
  const DbSeed._();

  /// [节次, 开始分钟, 结束分钟]
  static const List<List<int>> defaultSlots = <List<int>>[
    <int>[1, 480, 525], // 08:00 - 08:45
    <int>[2, 535, 580], // 08:55 - 09:40
    <int>[3, 600, 645], // 10:00 - 10:45
    <int>[4, 655, 700], // 10:55 - 11:40
    <int>[5, 840, 885], // 14:00 - 14:45
    <int>[6, 895, 940], // 14:55 - 15:40
    <int>[7, 960, 1005], // 16:00 - 16:45
    <int>[8, 1015, 1060], // 16:55 - 17:40
    <int>[9, 1140, 1185], // 19:00 - 19:45
    <int>[10, 1195, 1240], // 19:55 - 20:40
  ];

  /// 节次数量上限（设置页增删节次时使用）。
  static const int maxSlotCount = 16;

  static Future<void> insertDefaultTimeSlots(DatabaseExecutor db) async {
    final Batch batch = db.batch();
    for (final List<int> slot in defaultSlots) {
      batch.insert(DbConstants.tableTimeSlot, <String, Object?>{
        DbConstants.colSlotIndex: slot[0],
        DbConstants.colStartMinute: slot[1],
        DbConstants.colEndMinute: slot[2],
      });
    }
    await batch.commit(noResult: true);
  }
}

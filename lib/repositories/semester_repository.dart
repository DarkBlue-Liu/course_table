import '../domain/models/semester.dart';

/// 学期配置接口。1.0 只有一条记录（id 固定 1）。
abstract class SemesterRepository {
  /// 未设置学期时返回 null。
  Future<Semester?> getSemester();

  /// 写入/覆盖当前学期（单行）。
  Future<void> saveSemester(Semester semester);
}

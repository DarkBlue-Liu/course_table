/// 单双周标记：全部 / 单周 / 双周。
/// 奇偶按「绝对周号」判定（第 1 周为单周）。
enum WeekType {
  all(0, '每周'),
  odd(1, '单周'),
  even(2, '双周');

  const WeekType(this.value, this.label);

  final int value;
  final String label;

  static WeekType fromValue(int value) {
    for (final WeekType type in WeekType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return WeekType.all;
  }

  /// 第 [week] 周是否命中该单双周规则（不考虑起止周范围）。
  bool matchesWeek(int week) {
    switch (this) {
      case WeekType.all:
        return true;
      case WeekType.odd:
        return week.isOdd;
      case WeekType.even:
        return week.isEven;
    }
  }
}

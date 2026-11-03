import 'package:flutter/foundation.dart';

/// 极简日志：debug 输出，release 静默。禁止裸 print。
class Logger {
  const Logger._();

  static const String _tag = '[CourseTable]';

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('$_tag $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_tag ERROR $message ${error ?? ''}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}

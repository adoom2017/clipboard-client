import 'dart:developer' as developer;
import 'package:logging/logging.dart';

class AppLogger {
  static final Map<String, Logger> _loggers = {};

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      final message =
          '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}';

      // 输出到控制台
      developer.log(
        record.message,
        name: record.loggerName,
        level: _getLogLevel(record.level),
        time: record.time,
        error: record.error,
        stackTrace: record.stackTrace,
      );

      // 也可以使用print输出（在debug模式下更容易看到）
      if (record.level >= Level.INFO) {
        // ignore: avoid_print
        print(message);
      }
    });
  }

  static Logger getLogger(String name) {
    if (!_loggers.containsKey(name)) {
      _loggers[name] = Logger(name);
    }
    return _loggers[name]!;
  }

  static int _getLogLevel(Level level) {
    if (level == Level.SEVERE) return 1000;
    if (level == Level.WARNING) return 900;
    if (level == Level.INFO) return 800;
    if (level == Level.CONFIG) return 700;
    if (level == Level.FINE) return 500;
    if (level == Level.FINER) return 400;
    if (level == Level.FINEST) return 300;
    return 0;
  }
}

// 便捷的日志获取方法
Logger getLogger(String name) => AppLogger.getLogger(name);

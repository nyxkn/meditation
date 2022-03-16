import 'package:intl/intl.dart';

import 'package:f_logs/f_logs.dart';

Duration timeLeftTo(DateTime endTime) {
  Duration timeLeft = endTime.difference(DateTime.now()) + Duration(seconds: 1);
  return timeLeft;
}

void log(String tag, String text, [ LogLevel logLevel = LogLevel.INFO ] ) {
  FLog.logThis(
    className: DateTime.now().millisecondsSinceEpoch.toString(),
    methodName: tag.toUpperCase(),
    text: text,
    type: logLevel,
    // exception: null,
    // stacktrace: null,
  );
}

void logError(String tag, String text) {
  log(tag, text, LogLevel.ERROR);
}

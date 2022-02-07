import 'package:intl/intl.dart';

import 'package:flutter_logs/flutter_logs.dart';

Duration timeLeftTo(DateTime endTime) {
  Duration timeLeft = endTime.difference(DateTime.now()) + Duration(seconds: 1);
  return timeLeft;
}

void log(String tag, String message, [ LogLevel level = LogLevel.INFO ] ) {
  FlutterLogs.logThis(
    // tag: tag,
    // subTag: DateFormat.Hms().format(DateTime.now()),
    tag: DateTime.now().millisecondsSinceEpoch.toString(),
    subTag: tag.toUpperCase(),
    logMessage: message,
    level: level,
  );
}

void logError(String tag, String message) {
  log(tag, message, LogLevel.ERROR);
}

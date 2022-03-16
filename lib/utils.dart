import 'package:intl/intl.dart';

import 'package:logger/logger.dart';

Duration timeLeftTo(DateTime endTime) {
  Duration timeLeft = endTime.difference(DateTime.now()) + Duration(seconds: 1);
  return timeLeft;
}

// example of how you could extend Logger with a custom function that takes a tag parameter if you like
class NLogger extends Logger {
  void nlog(String tag, dynamic message, [Level level = Level.info, dynamic error, StackTrace? stackTrace]) {
    this.log(level, "${tag.toUpperCase()}: $message", error, stackTrace);
  }
}

var log = Logger(
  filter: null, // Use the default LogFilter (-> only log in debug mode)
  printer: PrettyPrinter( // Use the PrettyPrinter to format and print log
      methodCount: 0, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: false, // Print an emoji for each log message
      printTime: true // Should each log print contain a timestamp
  ),
  output: null, // Use the default LogOutput (-> send everything to console)
);

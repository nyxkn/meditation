import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:logger/logger.dart';

const maxTimerTime = 60;

final primaryColor = Colors.indigoAccent[100];
final secondaryColor = Colors.redAccent[100];

// String? timeInputValidator(String? input, { minTimerTime = 1 }) {
//   // var minTimerTime = 1;
//   if (input != null && input != "") {
//     var minutes = int.parse(input);
//     if (minutes >= minTimerTime && minutes <= maxTimerTime) {
//       return null;
//     }
//   }
//   return "Interval time should be a number between $minTimerTime and $maxTimerTime.";
// }

typedef Validator = String? Function(String?);
// Validator a = timeInputValidator(minTimerTime: 1) as Validator;

Function timeInputValidatorConstructor({minTimerTime = 1}) {
  String? validator(String? input) {
    if (input != null && input != "") {
      var minutes = int.parse(input);
      if (minutes >= minTimerTime && minutes <= maxTimerTime) {
        return null;
      }
    }
    return "Interval time should be a number between $minTimerTime and $maxTimerTime";
  }

  return validator;
}

Duration timeLeftTo(DateTime endTime) {
  Duration timeLeft = endTime.difference(DateTime.now()) + Duration(seconds: 1);
  return timeLeft;
}

// example of how you could extend Logger with a custom function that takes a tag parameter if you like
class NLogger extends Logger {
  void nlog(String tag, dynamic message,
      [Level level = Level.info, dynamic error, StackTrace? stackTrace]) {
    this.log(level, "${tag.toUpperCase()}: $message", error, stackTrace);
  }
}

var log = Logger(
  filter: null, // Use the default LogFilter (-> only log in debug mode)
  printer: PrettyPrinter(
      // Use the PrettyPrinter to format and print log
      methodCount: 0,
      // number of method calls to be displayed
      errorMethodCount: 8,
      // number of method calls if stacktrace is provided
      lineLength: 120,
      // width of the output
      colors: true,
      // Colorful log messages
      printEmojis: false,
      // Print an emoji for each log message
      printTime: true // Should each log print contain a timestamp
      ),
  output: null, // Use the default LogOutput (-> send everything to console)
);

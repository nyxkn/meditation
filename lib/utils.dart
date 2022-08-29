import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:logger/logger.dart';

// ========================================
// globals
// ========================================

const maxMeditationTime = 300;

final primaryColor = Colors.indigoAccent[100];
// we use this as our shade of red for errors
final secondaryColor = Colors.redAccent[100];


// ========================================
// utilities
// ========================================


typedef Validator = String? Function(String?);

Function timeInputValidatorConstructor({minTimerTime = 1, maxTimerTime = 60}) {
  String? validator(String? input) {
    if (input != null && input != "") {
      var minutes = int.parse(input);
      if (minutes >= minTimerTime && minutes <= maxTimerTime) {
        return null;
      }
    }
    return "Interval time should be a number between $minTimerTime and $maxTimerTime.";
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


List<int> getDurationNumbers(Duration d) {
  var microseconds = d.inMicroseconds;
  var microsecondsPerHour = Duration.microsecondsPerHour;
  var microsecondsPerMinute = Duration.microsecondsPerMinute;
  var microsecondsPerSecond = Duration.microsecondsPerSecond;

  var hours = microseconds ~/ microsecondsPerHour;
  microseconds = microseconds.remainder(microsecondsPerHour);

  // if (microseconds < 0) microseconds = -microseconds;

  var minutes = microseconds ~/ microsecondsPerMinute;
  microseconds = microseconds.remainder(microsecondsPerMinute);

  // var minutesPadding = minutes < 10 ? "0" : "";

  var seconds = microseconds ~/ microsecondsPerSecond;
  microseconds = microseconds.remainder(microsecondsPerSecond);

  // var secondsPadding = seconds < 10 ? "0" : "";
  //
  // var paddedMicroseconds = microseconds.toString().padLeft(6, "0");
  // return "$hours:"
  //     "$minutesPadding$minutes:"
  //     "$secondsPadding$seconds.$paddedMicroseconds";

  return [hours, minutes, seconds];
}

String formatSeconds(int seconds) {
  int mm = seconds ~/ 60;
  int ss = seconds % 60;
  return mm.toString().padLeft(2, '0') + ':' + ss.toString().padLeft(2, '0');
}

String formatDuration(Duration d) {
  var formattedString = d.toString().split('.').first;
  if (formattedString[0] == '0') {
    // if we have 0 hours, remove hours
    formattedString = formattedString.substring(2);
  }

  if (d.isNegative) {
    return '-$formattedString';
  } else {
    return formattedString;
  }
}

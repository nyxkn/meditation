import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:intl/intl.dart';

import 'package:meditation/main.dart';
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

void requestBackgroundPermission(context) async {
  // checking and asking permissions for flutter_background
  if (await FlutterBackground.hasPermissions) {
    return;
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text("Setup permissions"),
      // removing bottom padding from contentPadding. looks better.
      // contentPadding defaults: https://api.flutter.dev/flutter/material/AlertDialog/contentPadding.html
      contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text("On the next screen, please choose to allow the app to run in the background.\n"),
            Text(
                "This is required to ensure that the timer can work reliably even when the app isn't focused or when the screen turns off.\n"),
            // Text("This feature will only be used when the timer is running."),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed: () async {
            Navigator.of(context).pop();
            // this init call is just to ask for permission
            await initFlutterBackground();
          },
        ),
      ],
    ),
  );
}

Future<List<NotificationPermission>> checkMissingNotificationPermissions() async {
  List<NotificationPermission> permissionList = [
    NotificationPermission.Alert,
    // NotificationPermission.Sound
  ];

  List<NotificationPermission> permissionsAllowed =
      await AwesomeNotifications().checkPermissionList(
    channelKey: 'timer-main',
    permissions: permissionList,
  );

  var notificationsOkay = false;
  if (permissionsAllowed.length == permissionList.length) {
    return [];
  } else {
    List<NotificationPermission> permissionsNeeded =
        permissionList.toSet().difference(permissionsAllowed.toSet()).toList();
    return permissionsNeeded;
  }
}

void forceRequestNotifications(context, permissionList) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Setup permissions'),
        content: const Text("On the next screen, please enable notifications for the app.\n\n"
            "There are required for notifying you of when the timed session ends.\n\n"),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );

  // if called without params, defaults to Alert, Badge, Sound, Vibrate and Light.
  // badge is broken because we've removed me.leolin.shortcutbadger stuff in the gradle build
  // AwesomeNotifications().requestPermissionToSendNotifications();
  AwesomeNotifications().requestPermissionToSendNotifications(
      // channelKey: 'timer-main',
      permissions: permissionList);
}

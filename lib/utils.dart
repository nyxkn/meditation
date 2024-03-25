import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'package:meditation/main.dart';
import 'package:logger/logger.dart';

// ========================================
// globals
// ========================================

const maxMeditationTime = 300;

final primaryColor = Colors.indigoAccent[100];
const darkGray = Color(0xFF121212);
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
// class NLogger extends Logger {
//   void nlog(String tag, dynamic message,
//       [Level level = Level.info, dynamic error, StackTrace? stackTrace]) {
//     this.log(level, "${tag.toUpperCase()}: $message", error: error, stackTrace: stackTrace);
//   }
// }

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
      title: Text("Background permissions"),
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

Future<(bool, List<NotificationPermission>)> requestUserPermissions(BuildContext context,
    {
// if you only intends to request the permissions until app level, set the channelKey value to null
    required String? channelKey,
    required List<NotificationPermission> permissionList}) async {
  bool requestedUserAction = false;

// Check which of the permissions you need are allowed at this time
  List<NotificationPermission> permissionsAllowed = await AwesomeNotifications()
      .checkPermissionList(channelKey: channelKey, permissions: permissionList);

// If all permissions are allowed, there is nothing to do
  if (permissionsAllowed.length == permissionList.length)
    return (requestedUserAction, permissionsAllowed);

// Refresh the permission list with only the disallowed permissions
  List<NotificationPermission> permissionsNeeded =
      permissionList.toSet().difference(permissionsAllowed.toSet()).toList();

// Check if some of the permissions needed request user's intervention to be enabled
  List<NotificationPermission> lockedPermissions = await AwesomeNotifications()
      .shouldShowRationaleToRequest(channelKey: channelKey, permissions: permissionsNeeded);

// If there is no permissions depending on user's intervention, so request it directly
  if (lockedPermissions.isEmpty) {
// Request the permission through native resources.
    await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: channelKey, permissions: permissionsNeeded);

// After the user come back, check if the permissions has successfully enabled
    permissionsAllowed = await AwesomeNotifications()
        .checkPermissionList(channelKey: channelKey, permissions: permissionsNeeded);
  } else {
// If you need to show a rationale to educate the user to conceived the permission, show it
    if (channelKey != null) {
      // user has manually disabled or modified a channel, which makes this really hard to solve
      // you'd have to ask the user to disable the channel and reenable it
      // that seems to always set the needed permissions
      // but you can't really lock the app on an endless dialog if the user doesn't comply
      // you could at least detect if the channel was disabled and ask to re-enable
      // but you can't check for channel enabled status without also checking for a specific permission
      // so you could check for something like light, but you cannot check for something like alert
      // because alert can't seem to be activated manually
      // i'd say the best bet is to just not do anything
      // we also don't know how it works on every version of android
      log.e(
          "channel permissions have been tampered with. couldn't enable: ${lockedPermissions} on channel: ${channelKey}");
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue with notification settings. If app doesn't work, try uninstalling and reinstalling")));
//       await showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//                 title: const Text('Issue with notifications'),
//                 content: const Text(
//                     "There is a problem with the notification permissions for this app.\n\n"
//                     "On the next screen, please disable and re-enabled the shown notification channel.\n\n"
//                     "These are required for reliably notifying you of when the meditation session ends.\n\n"),
//                 actions: <Widget>[
//                   TextButton(
//                     style: TextButton.styleFrom(
//                       textStyle: Theme.of(context).textTheme.labelLarge,
//                     ),
//                     child: const Text('OK'),
//                     onPressed: () async {
// // Request the permission through native resources. Only one page redirection is done at this point.
//                       await AwesomeNotifications().requestPermissionToSendNotifications(
//                           channelKey: channelKey, permissions: lockedPermissions);
//
// // After the user come back, check if the permissions has successfully enabled
//                       permissionsAllowed = await AwesomeNotifications().checkPermissionList(
//                           channelKey: channelKey, permissions: lockedPermissions);
//
//                       Navigator.of(context).pop();
//                     },
//                   ),
//                 ],
//               ));
    } else {
      requestedUserAction = true;
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Enable notifications'),
                content: const Text(
                    "On the next screen, please allow notifications for the app.\n\n"
                    "These notifications are required for reliably notifying you of when the meditation session ends.\n\n"),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    child: const Text('OK'),
                    onPressed: () async {
// Request the permission through native resources. Only one page redirection is done at this point.
                      await AwesomeNotifications().requestPermissionToSendNotifications(
                          channelKey: channelKey, permissions: lockedPermissions);

// After the user come back, check if the permissions has successfully enabled
                      permissionsAllowed = await AwesomeNotifications().checkPermissionList(
                          channelKey: channelKey, permissions: lockedPermissions);

                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ));
    }
  }

// Return the updated list of allowed permissions
  return (requestedUserAction, permissionsAllowed);
}

Future<void> requestUserToEnableChannel(context, channelKey) async {
  await showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Enable notification channel'),
    content: const Text(
        "On the next screen, please enable the shown notification channel.\n\n"
            "These notifications are required for reliably notifying you of when the meditation session ends.\n\n"),
    actions: <Widget>[
      TextButton(
        style: TextButton.styleFrom(
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: const Text('OK'),
        onPressed: () async {
          var helper = ChannelHelper();
          bool isChannelEnabled = await helper.isNotificationChannelEnabled(channelKey);
          if (!isChannelEnabled) {
            helper.openNotificationChannelSettings(channelKey);
          }

          Navigator.of(context).pop();
        },
      ),
    ],
  ));
}

class ChannelHelper {
  static const platform = MethodChannel('com.nyxkn.meditation/channelHelper');

  Future<bool> isNotificationChannelEnabled(String channelId) async {
    try {
      final bool isEnabled = await platform.invokeMethod('isChannelEnabled', {'channelId': channelId});
      return isEnabled;
    } on PlatformException catch (e) {
      print("Error checking notification channel status: ${e.message}");
      return false;
    }
  }

  Future<void> openNotificationChannelSettings(String channelId) async {
    try {
      await platform.invokeMethod('openChannelSettings', {'channelId': channelId});
    } on PlatformException catch (e) {
      print("Failed to open channel settings: ${e.message}");
    }
  }
}

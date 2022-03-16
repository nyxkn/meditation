import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:meditation/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';

import 'package:meditation/audioplayer.dart';
import 'package:meditation/utils.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({Key? key}) : super(key: key);

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> with SingleTickerProviderStateMixin {
  final int endingNotificationID = 99;

  late Ticker ticker;

  bool meditating = false;
  int timerMinutes = 0;
  String timerButtonText = "begin";

  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();
  Duration timeLeft = const Duration(minutes: 0, seconds: 0);
  double timerProgress = 0.0;

  @override
  void initState() {
    super.initState();

    ticker = createTicker(updateTimer);

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        timerMinutes = prefs.getInt('timer-minutes') ?? 0;
      });
    });

    AwesomeNotifications().displayedStream.listen((ReceivedNotification receivedNotification) {
      // on ios this doesn't seem to get called immediately
      // so if the app isn't in the foreground, onTimerEnd execution is delayed
      // this likely doesn't allow the sound to play on time
      // so you'd rather have to play it through the notification
      // or find another way of executing code when the app is not in the foreground
      log("awesome-notifications", "notification displayed. id = ${receivedNotification.id}");
      if (receivedNotification.id == endingNotificationID) {
        if (meditating) {
          log("timer-end", "ending timer through displayedStream notification callback");
          onTimerEnd();
        }
      }
    });
  }

  @override
  void dispose() {
    AwesomeNotifications().cancelAll();
    ticker.dispose();

    super.dispose();
  }

  String formatSeconds(int seconds) {
    int mm = seconds ~/ 60;
    int ss = seconds % 60;
    return mm.toString().padLeft(2, '0') + ':' + ss.toString().padLeft(2, '0');
  }

  String formatDuration(Duration d) {
    String formattedString = d.toString().split('.').first.substring(2);
    if (d.isNegative) {
      return '-$formattedString';
    } else {
      return formattedString;
    }
  }

  void updateTimer(Duration elapsed) {
    if (!meditating) {
      return;
    } else {
      // backup system for ending the timer in case notification fails
      if (timeLeft.inSeconds <= 0) {
        log("timer-end", "ending timer through updateTimer");
        onTimerEnd();
      }
    }

    // invlerp: t = (v-a) / (b-a);
    int va = DateTime.now().difference(startTime).inMilliseconds;
    int ba = endTime.difference(startTime).inMilliseconds;
    double t = va / ba;

    setState(() {
      timerProgress = t;
      timeLeft = timeLeftTo(endTime);
    });
  }

  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      // checking and asking permissions for flutter_background
      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text("Permission required"),
            // removing bottom padding from contentPadding. looks better.
            // contentPadding defaults: https://api.flutter.dev/flutter/material/AlertDialog/contentPadding.html
            contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                      "On the next screen you'll be asked to allow the app to run in the background.\n"),
                  Text(
                      "This is to ensure the timer can work reliably even when the app isn't focused or when the screen turns off.\n"),
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

        // doesn't matter whether we were granted permission or not.
        // we do not start the timer. we wait for a new press instead.
        return false;
      } else {
        // if we do have permissions, go ahead and initialize without worry of permission being asked again
        await initFlutterBackground();
      }
    }

    // return true if there were no permissions to check
    return true;
  }

  void onTimerButtonPress() async {
    if (!meditating) {
      // start
      if (await checkPermissions() == true) {
        onTimerStart();
      }
    } else {
      // manual stop
      if (DateTime.now().difference(startTime).inSeconds < 1) {
        // prevent accidental double tap
        return;
      }
      // AwesomeNotifications().cancelSchedule(endingNotificationID);
      AwesomeNotifications().cancel(endingNotificationID);
      // onTimerEnd(playAudio: true);
      if (kReleaseMode) {
        onTimerEnd(playAudio: false);
      } else {
        onTimerEnd(playAudio: true);
      }
    }
  }

  void onTimerEnd({bool playAudio = true}) async {
    // log("timer-end", "called");
    // making sure this doesn't get called twice
    // since we do use the backup check on timerUpdate
    // as well as the notification
    if (!meditating) {
      logError("timer-end", "onTimerEnd called when it shouldn't have");
      return;
    }

    // removing 'meditation started' snackbar in case it's still showing
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    meditating = false;
    ticker.stop();
    Wakelock.disable();

    setState(() {
      // one last update so we know how much we were off on timeout
      timeLeft = timeLeftTo(endTime);
      timerButtonText = "begin";
    });

    if (Platform.isAndroid) {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        bool backgroundSuccess = await FlutterBackground.disableBackgroundExecution();
        log("timer-end", 'disable flutter_background: success = $backgroundSuccess');
      } else {
        logError("timer-end", "background wasn't enabled. why?");
      }

      // only dismiss on android
      Timer(const Duration(seconds: 10), () {
        log("timer-end", "dismissing end notification");
        AwesomeNotifications().dismiss(endingNotificationID);
      });
    }

    NAudioPlayer audioPlayer = GetIt.I.get<NAudioPlayer>();
    if (playAudio) {
      audioPlayer.playSound('end-sound');
    } else {
      audioPlayer.stopPrevious();
    }
  }

  void onTimerStart() async {
    // cleaning up endingnotification in case it's still around
    // 10s timer for dismissal at onTimerEnd will still call and presumably do nothing
    // probably no need to fix that
    AwesomeNotifications().dismiss(endingNotificationID);

    startTime = DateTime.now();
    if (timerMinutes == 0) {
      // this is the test mode
      endTime = startTime.add(Duration(seconds: 10));
    } else {
      endTime = startTime.add(Duration(minutes: timerMinutes));
    }
    timeLeft = timeLeftTo(endTime);

    meditating = true;
    ticker.start();

    setState(() {
      timerButtonText = "end";
    });

    if (Settings.getValue<bool>('screen-wakelock', false) == true) {
      log('timer-start', 'enabling screen wakelock');
      Wakelock.enable();
    }

    if (Platform.isAndroid) {
      bool backgroundSuccess = await FlutterBackground.enableBackgroundExecution();
      log("timer-start", 'enable background success: $backgroundSuccess');
    }

    await scheduleEndingNotification();

    NAudioPlayer audioPlayer = GetIt.I.get<NAudioPlayer>();
    audioPlayer.playSound('start-sound');

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meditation started')));
  }

  Future<void> scheduleEndingNotification() async {
    String localTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: endingNotificationID,
        channelKey: 'timer-end',
        title: 'Meditation ended',
        body: 'Tap to return to app',
        icon: 'resource://drawable/ic_notification',
        largeIcon: 'resource://mipmap/ic_launcher',
        // Alarm and Event seem to both show up in dnd mode (this is what we want)
        // Alarm also makes the notification undismissable with swiping and requires interaction
        // which we probably don't want
        // Event instead is dismissable
        // category: NotificationCategory.Alarm,
        category: NotificationCategory.Event,
        // notificationLayout: NotificationLayout.Default,
        notificationLayout: NotificationLayout.BigPicture,
        autoDismissible: true,
        wakeUpScreen: true,
        // fullScreenIntent keeps showing the notification popup permanently until user dismisses it
        // so we will dismiss this automatically after a few seconds
        fullScreenIntent: true,
      ),
      schedule: NotificationInterval(
          interval: timeLeft.inSeconds,
          timeZone: localTimeZone,
          allowWhileIdle: true,
          preciseAlarm: true),
      // actionButtons: [
      //   NotificationActionButton(
      //     key: 'dismiss',
      //     label: 'Dismiss',
      //     autoDismissible: true,
      //   ),
      // ],
    );
  }

  Future<void> showTimeChoice() async {
    var timeChoices = [5, 10, 15, 20, 25, 30, 45, 60];
    var _selected = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Select time'),
            //@formatter:off
            children: <Widget>[
              if (!kReleaseMode) SimpleDialogOption(
                onPressed: () { Navigator.pop(context, 0); },
                child: const Text('0 - 10s'),
              ),
              SimpleDialogOption(
                onPressed: () { Navigator.pop(context, 1); },
                child: const Text('1 minute'),
              ),
              for (var t in timeChoices) SimpleDialogOption(
                onPressed: () { Navigator.pop(context, t); },
                child: Text('$t minutes'),
              )
            ],
            //@formatter:on
          );
        });

    setState(() {
      timerMinutes = _selected;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('timer-minutes', timerMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        if (!Settings.getValue<bool>('hide-countdown', false))
          Align(
              alignment: Alignment(0, -0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatDuration(timeLeft), style: Theme.of(context).textTheme.bodyText1),
                ],
              )),
        SizedBox(
          width: MediaQuery.of(context).size.shortestSide / 1.5,
          height: MediaQuery.of(context).size.shortestSide / 1.5,
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment(0, -0.1),
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.shortestSide / 1.5,
                      height: MediaQuery.of(context).size.shortestSide / 1.5,
                      child: CircularProgressIndicator(
                        value: meditating ? timerProgress : 0.0,
                        strokeWidth: 10,
                      ),
                    ),
                    TextButton(
                      style: timerButtonStyle,
                      onPressed: () {
                        onTimerButtonPress();
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.shortestSide / 1.75,
                        height: MediaQuery.of(context).size.shortestSide / 1.75,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Text(timerButtonText.toUpperCase()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment(0, 0.8),
          child: TextButton(
            style: timeSelectionButtonStyle,
            onPressed: () {
              showTimeChoice();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 30,
                ),
                Text(
                  ' ${timerMinutes}m',
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

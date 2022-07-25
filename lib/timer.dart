import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:meditation/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';

import 'package:meditation/audioplayer.dart';
import 'package:meditation/utils.dart';

enum TimerState { stopped, delaying, meditating }

class TimerWidget extends StatefulWidget {
  const TimerWidget({Key? key}) : super(key: key);

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> with SingleTickerProviderStateMixin {
  final int endingNotificationID = 100;
  final int intervalNotificationID = 101;

  late Ticker ticker;

  TimerState timerState = TimerState.stopped;
  int timerMinutes = 0;
  int timerDelaySeconds = 0;
  String timerButtonText = "begin";

  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();
  Duration timeLeft = const Duration(minutes: 0, seconds: 0);
  double timerProgress = 0.0;

  bool intervalsEnabled = false;
  Duration intervalTime = const Duration(minutes: 0);
  int intervalCount = 0;

  @override
  void initState() {
    super.initState();

    ticker = createTicker(timerUpdate);
    // timerDelayTicker = createTicker(timerDelayUpdate);

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
      log.i("notification displayed. id = ${receivedNotification.id}");
      if (receivedNotification.id == endingNotificationID) {
        if (timerState == TimerState.meditating) {
          log.i("ending timer through displayedStream notification callback");
          onTimerEnd();
        }
      }
      if (receivedNotification.id == intervalNotificationID) {
        if (timerState == TimerState.meditating) {
          log.i("reached interval timer through displayedStream notification callback");
          onTimerInterval();
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

  void timerUpdate(Duration elapsed) {
    if (timerState == TimerState.stopped) {
      return;
    }

    if (timerState == TimerState.delaying) {
      // delaying

      var countdown = timerDelaySeconds - elapsed.inSeconds;

      setState(() {
        timerButtonText = countdown.toString();
      });

      if (elapsed.inSeconds > timerDelaySeconds - 1) {
        // done delaying
        onMeditationStart();
      }
    }

    if (timerState == TimerState.meditating) {
      // meditating

      // backup system for ending the timer in case notification fails
      if (timeLeft.inSeconds <= 0) {
        log.i("ending timer through updateTimer");
        onTimerEnd();
        return;
      }

      var timeElapsed = DateTime.now().difference(startTime);

      if (intervalsEnabled && intervalCount > 0) {
        if (timeLeft <= intervalTime * intervalCount) {
          intervalCount -= 1;
          onTimerInterval();
        }
      }

      // invlerp: t = (v-a) / (b-a);
      int vma = timeElapsed.inMilliseconds;
      int bma = endTime.difference(startTime).inMilliseconds;
      double t = vma / bma;

      setState(() {
        timerProgress = t;
        timeLeft = timeLeftTo(endTime);
      });
    }
  }

  void onTimerButtonPress() async {
    if (timerState == TimerState.stopped) {
      // start
      if (await checkPermissions() == true) {
        timerDelaySeconds = int.parse(Settings.getValue<String>('delay-time') ?? '0');
        ticker.start();
        onTimerStart();

        if (timerDelaySeconds >= 1) {
          // start delay
          timerState = TimerState.delaying;
          // onTimerStart() will be called at the end of the elapsed time
        } else {
          // start meditation
          onMeditationStart();
        }
      }
    } else {
      // manual stop
      if (timerDelaySeconds == 0 && DateTime.now().difference(startTime).inSeconds < 1) {
        // prevent accidental double tap
        // but not if coming from the delayed start
        return;
      }
      // AwesomeNotifications().cancelSchedule(endingNotificationID);
      AwesomeNotifications().cancel(endingNotificationID);
      AwesomeNotifications().cancel(intervalNotificationID);
      // onTimerEnd(playAudio: true);
      if (kReleaseMode) {
        onTimerEnd(playAudio: false);
      } else {
        onTimerEnd(playAudio: true);
      }
    }
  }

  void onTimerInterval() async {
    if (timerState != TimerState.meditating) {
      log.e("onTimerInterval called after meditation finished");
      return;
    }

    log.d("played interval sound at $timeLeft");

    NAudioPlayer audioPlayer = GetIt.I.get<NAudioPlayer>();
    audioPlayer.playSound('interval-sound');
  }

  // this happens on either start or delay
  void onTimerStart() async {
    // cleaning up endingnotification in case it's still around
    // 10s timer for dismissal at onTimerEnd will still call and presumably do nothing
    // probably no need to fix that
    AwesomeNotifications().dismiss(endingNotificationID);

    if (Settings.getValue<bool>('screen-wakelock') == true) {
      log.i('enabling screen wakelock');
      Wakelock.enable();
    }

    if (Settings.getValue<bool>('dnd') == true) {
      log.i('enabling dnd');
      await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALARMS);
    }

    if (Platform.isAndroid) {
      bool backgroundSuccess = await FlutterBackground.enableBackgroundExecution();
      log.i('enable background success: $backgroundSuccess');
    }

    await scheduleEndingNotification();
  }

  // pretty much just the visual/aural part and the switch of state
  void onMeditationStart() async {
    timerState = TimerState.meditating;

    setState(() {
      print("setstate ontimerstart");
      timerButtonText = "end";
    });

    startTime = DateTime.now();
    if (timerMinutes == 0) {
      // this is the test mode
      endTime = startTime.add(Duration(seconds: 10));
    } else {
      endTime = startTime.add(Duration(minutes: timerMinutes));
    }
    // initial calculation
    timeLeft = timeLeftTo(endTime);

    intervalsEnabled = Settings.getValue<bool>('intervals-enabled') ?? false;
    if (intervalsEnabled) {
      intervalTime =
          Duration(minutes: int.parse(Settings.getValue<String>('interval-time') ?? '0'));
      if (intervalTime.inMinutes >= 1) {
        log.i('enabling intervals');
        var diff = endTime.difference(startTime);
        intervalCount = (diff.inMinutes / intervalTime.inMinutes).floor();
        if (diff.inMinutes % intervalTime.inMinutes == 0) {
          // if no remainder, then we remove the last count
          // which would happen together with the end bell
          intervalCount -= 1;
        }
        log.d("interval count: $intervalCount");
        // await scheduleIntervalNotification();
      }
    }

    NAudioPlayer audioPlayer = GetIt.I.get<NAudioPlayer>();
    audioPlayer.playSound('start-sound');

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meditation started')));
  }

  void onTimerEnd({bool playAudio = true}) async {
    // log.i("timer-end", "called");
    // making sure this doesn't get called twice
    // since we do use the backup check on timerUpdate
    // as well as the notification
    if (timerState == TimerState.stopped) {
      // if (!meditating) {
      log.e("onTimerEnd called when it shouldn't have");
      return;
    }

    // removing 'meditation started' snackbar in case it's still showing
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    timerState = TimerState.stopped;
    ticker.stop();

    setState(() {
      // one last update so we know how much we were off on timeout
      timeLeft = timeLeftTo(endTime);
      log.d("ending meditation at timeLeft: $timeLeft");
      timerButtonText = "begin";
    });

    Wakelock.disable();

    if (Settings.getValue<bool>('dnd') == true) {
      log.i('disabling dnd');
      await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALL);
    }

    if (Platform.isAndroid) {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        bool backgroundSuccess = await FlutterBackground.disableBackgroundExecution();
        log.i("disable flutter_background: success = $backgroundSuccess");
      } else {
        log.e("background wasn't enabled. why?");
      }
    }

    if (Platform.isAndroid) {
      // only dismiss on android
      Timer(const Duration(seconds: 10), () {
        log.i("dismissing end notification");
        AwesomeNotifications().dismiss(endingNotificationID);
      });
      AwesomeNotifications().dismiss(intervalNotificationID);
    }

    NAudioPlayer audioPlayer = GetIt.I.get<NAudioPlayer>();
    if (playAudio) {
      audioPlayer.playSound('end-sound');
    } else {
      audioPlayer.stopPrevious();
    }
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

  Future<void> scheduleIntervalNotification() async {
    String localTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: intervalNotificationID,
        channelKey: 'timer-interval',
        title: 'Meditation interval',
        body: 'Tap to return to app',
        icon: 'resource://drawable/ic_notification',
        largeIcon: 'resource://mipmap/ic_launcher',
        category: NotificationCategory.Event,
        notificationLayout: NotificationLayout.BigPicture,
        autoDismissible: true,
        wakeUpScreen: true,
        fullScreenIntent: false,
      ),
      schedule: NotificationInterval(
          interval: intervalTime.inSeconds,
          timeZone: localTimeZone,
          repeats: true,
          allowWhileIdle: true,
          preciseAlarm: true),
    );
  }

  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      // checking and asking permissions for flutter_background
      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        await showDialog(
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

  Future<void> showTimeChoice() async {
    var minutes;
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
              ),
              SimpleDialogOption(
                onPressed: () { Navigator.pop(context, -1); },
                child: const Text('custom...'),
              ),
            ],
            //@formatter:on
          );
        });

    if (_selected == null) {
      // we just closed the dialog without choosing anything
      return;
    }

    if (_selected >= 0) {
      // preset chosen
      minutes = _selected;
    } else if (_selected == -1) {
      // inputting custom time
      final Color borderColor = primaryColor!;
      final Color errorColor = secondaryColor!;
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      var cancelled = true;

      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('Input time'),
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  // do we need the form?
                  child: Form(
                    key: formKey,
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      controller: controller,
                      autofocus: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        FilteringTextInputFormatter.deny(RegExp(r"^0")),
                      ],
                      validator: timeInputValidatorConstructor() as Validator,
                      decoration: InputDecoration(
                        helperText: "Input time in minutes.",
                        errorMaxLines: 3,
                        errorStyle: TextStyle(
                          color: errorColor,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(5.0),
                          ),
                          borderSide: BorderSide(color: errorColor),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(5.0),
                          ),
                          borderSide: BorderSide(
                            color: borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(5.0),
                          ),
                          borderSide: BorderSide(
                            color: borderColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ButtonBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text("CANCEL"),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    TextButton(
                      child: Text("OK"),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          cancelled = false;
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          });

      if (cancelled) {
        // pressed cancel or outside the dialog
        return;
      } else {
        minutes = int.parse(controller.text);
      }
    }

    if (minutes == null) {
      log.e("we didn't get to choose any value for minutes. something went very wrong");
    }

    setState(() {
      timerMinutes = minutes;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('timer-minutes', timerMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        if (Settings.getValue<bool>('show-countdown') == true)
          Align(
              alignment: Alignment(0, -0.75),
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
                        value: timerState == TimerState.meditating ? timerProgress : 0.0,
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
          alignment: Alignment(0, 0.78),
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

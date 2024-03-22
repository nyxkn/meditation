import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meditation/audioplayer.dart';
import 'package:meditation/settings.dart';
import 'package:meditation/timer.dart';
import 'package:meditation/utils.dart';

// on the very first call to initialize, android will ask to allow notifications
// there is no way to retrigger this popup, and instead you'll have to redirect user to the settings
// so call init once on first start
// then have a function to check notifications
// and if notifications aren't enabled, show information popup and redirect to settings
Future<void> initNotifications() async {
  // initialize and set a default channel
  bool success = await AwesomeNotifications().initialize(
    // set the icon to null if you want to use the default app icon
    //   'resource://drawable/res_app_icon',
    null,
    [
      NotificationChannel(
        channelKey: 'timer-main',
        channelName: 'Timer notifications',
        channelDescription: 'Critical notifications displayed during meditation',
        defaultColor: secondaryColor,
        importance: NotificationImportance.Max,
        // this enables critical alerts
        criticalAlerts: true,
        playSound: false,
        enableVibration: false,
      ),
      NotificationChannel(
        channelKey: 'timer-internal',
        channelName: 'Timer (support)',
        channelDescription: 'Internal notifications used by the app. Must stay enabled',
        defaultColor: secondaryColor,
        // urgent: makes sound and appears as heads up
        // high/default: makes sound
        // medium/low: no sound
        // min: no sound and does not appear in status bar
        importance: NotificationImportance.Min,
        criticalAlerts: true,
        playSound: false,
        enableVibration: false,
      ),
    ],
    // Channel groups are only visual and are not required
    // channelGroups: [
    //   NotificationChannelGroup(
    //       channelGroupkey: 'default-channel-group', channelGroupName: 'Default group')
    // ],
    // debug: true
  );
  log.i('awesome_notifications init: success = $success');
}

Future<void> initFlutterBackground() async {
  // if (!Platform.isAndroid) {
  //   return;
  // }

  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Meditation in progress",
    notificationText: "Foreground service notification to keep the app running",
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: 'ic_notification', defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );

  bool success = await FlutterBackground.initialize(androidConfig: androidConfig);
  log.i('flutter_background init: success = $success');
}

Future<void> initDefaultSettings() async {
  // in case there's no stored value for a setting, set a default one
  // this happens on a fresh install (or if you add a setting)
  // do not rely on the settingstile default value. that seems to only be visual

  if (Settings.getValue<double>('volume') == null) {
    await Settings.setValue<double>('volume', 6);
  }

  if (Settings.getValue<int>('start-sound') == null) {
    var startSoundId = audioFiles.values.toList().indexOf('Singing Bowl');
    await Settings.setValue<int>('start-sound', startSoundId);
  }

  if (Settings.getValue<int>('end-sound') == null) {
    var endSoundId = audioFiles.values.toList().indexOf('Burma Bell');
    await Settings.setValue<int>('end-sound', endSoundId);
  }

  if (Settings.getValue<int>('interval-sound') == null) {
    var intervalSoundId = audioFiles.values.toList().indexOf('Meditation Bell');
    await Settings.setValue<int>('interval-sound', intervalSoundId);
  }

  if (Settings.getValue<String>('interval-time') == null) {
    await Settings.setValue<String>('interval-time', '5');
  }

  if (Settings.getValue<bool>('show-countdown') == null) {
    await Settings.setValue<bool>('show-countdown', true);
  }

  if (Settings.getValue<String>('delay-time') == null) {
    await Settings.setValue<String>('delay-time', '0');
  }
}

Future<void> initDefaultPrefs() async {
  final prefs = await SharedPreferences.getInstance();

  // setting defaults in case there's no stored value (on fresh install or new setting)

  if ((prefs.getInt('timer-minutes') ?? -1) == -1) {
    prefs.setInt('timer-minutes', 15);
  }
}

void main() async {
  // Be sure to add this line if initialize() call happens before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  GetIt.I.registerSingleton<NAudioPlayer>(NAudioPlayer());
  GetIt.I.registerSingleton<Logger>(Logger());

  await Settings.init();

  await initDefaultSettings();
  await initDefaultPrefs();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditation Timer',
      theme: ThemeData(
          colorScheme: ColorScheme.dark().copyWith(
            // primary: Colors.indigoAccent[100];
            // primary: Colors.redAccent[100],
            // primary: Colors.deepPurpleAccent[100], // this seems to be close to the default
            primary: primaryColor,
            background: Colors.black,
            surface: Colors.black,
            secondary: primaryColor,
          ),
          scaffoldBackgroundColor: Color(0xFF121212),
          // scaffoldBackgroundColor: Colors.black,
          // scaffoldBackgroundColor: Colors.grey[900],
          typography: Typography.material2018(),
          backgroundColor: Colors.black,
          canvasColor: Colors.grey[900],
          dialogBackgroundColor: Colors.grey[900],
          snackBarTheme: SnackBarThemeData(
            backgroundColor: Colors.grey[900],
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          progressIndicatorTheme: ProgressIndicatorThemeData(
            // circularTrackColor: Colors.black,
            circularTrackColor: Colors.grey[900],
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              // primary: Colors.grey[300],
              backgroundColor: Colors.grey[300],
            ),
          ),
          textTheme: Typography().white.copyWith(
                bodyText1: Typography().white.bodyText1?.copyWith(
                      // fontSizeFactor: 1.2,
                      fontSize: 18,
                      color: Colors.grey[500],
                      // fontWeight: FontWeight.w400,
                    ),
                bodyText2: Typography().white.bodyText2?.copyWith(
                      // fontSizeFactor: 1.2,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      height: 2,
                      color: Colors.white,
                    ),
              )),
      home: const Home(),
    );
  }
}

TextStyle? largeButtonsTextStyle = Typography().white.button?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.8,
    );

ButtonStyle timerButtonStyle = TextButton.styleFrom(
  textStyle: largeButtonsTextStyle,
  shape: CircleBorder(),
);

ButtonStyle timeSelectionButtonStyle = TextButton.styleFrom(
  textStyle: largeButtonsTextStyle,
);

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => afterBuild(context));

    return Scaffold(
      appBar: AppBar(
        title: Text('Meditation Timer'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsWidget()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: TimerWidget(),
      ),
    );
  }

  void afterBuild(context) async {
    await Future.delayed(Duration(milliseconds: 500));
    // this will ask for permission if first app run
    initNotifications();
  }
}

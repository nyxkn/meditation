import 'dart:io';

import 'package:flutter/material.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meditation/audioplayer.dart';
import 'package:meditation/settings.dart';
import 'package:meditation/timer.dart';
import 'package:meditation/utils.dart';

Future<void> initNotifications() async {
  // initialize and set a default channel
  bool success = await AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      //   'resource://drawable/res_app_icon',
      null,
      [
        NotificationChannel(
            channelGroupKey: 'default-channel-group',
            channelKey: 'default-channel',
            channelName: 'Default notification channel',
            channelDescription: 'Basic notifications',
            defaultColor: Color(0xFF9D50DD),
            // medium purple
            ledColor: Colors.white)
      ],
      // Channel groups are only visual and are not required
      channelGroups: [
        NotificationChannelGroup(
            channelGroupkey: 'default-channel-group', channelGroupName: 'Default group')
      ],
      debug: true);
  log('init', 'awesome_notifications init: success = $success');

  // FIXME show dialog first before asking for permission
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      log('init', 'awesome_notifications: asking for permission');
      // This is just a basic example. For real apps, you must show some
      // friendly dialog box before call the request method.
      // This is very important to not harm the user experience
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // forceUpdate throws an exception. not sure how to use it. check github issues
  await AwesomeNotifications().setChannel(
      NotificationChannel(
        channelKey: 'timer-end',
        channelName: 'Timer end',
        channelDescription: 'Notifications displayed at the end of meditation',
        defaultColor: Colors.red,
        importance: NotificationImportance.Max,
        playSound: false,
        enableVibration: false,
      ),
      forceUpdate: false);
}

Future<void> initFlutterBackground() async {
  if (!Platform.isAndroid) {
    return;
  }

  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Meditation in progress",
    notificationText:
        "Background notification for keeping Meditation Timer running in the background",
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: '@mipmap/ic_launcher',
        defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );

  bool success = await FlutterBackground.initialize(androidConfig: androidConfig);
  log('init', 'flutter_background init: success = $success');
}

Future<void> initLogging() async {
  //Initialize Logging
  String success = await FlutterLogs.initLogs(
      logLevelsEnabled: [LogLevel.INFO, LogLevel.WARNING, LogLevel.ERROR, LogLevel.SEVERE],
      // timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
      timeStampFormat: TimeStampFormat.TIME_FORMAT_24_FULL,
      directoryStructure: DirectoryStructure.FOR_DATE,
      logTypesEnabled: ["device", "network", "errors"],
      logFileExtension: LogFileExtension.LOG,
      logsWriteDirectoryName: "MyLogs",
      logsExportDirectoryName: "MyLogs/Exported",
      debugFileOperations: true,
      isDebuggable: true);

  log('init', 'flutter_logs init: success = $success');
}

Future<void> initDefaultSettings() async {
  // in case there's no stored value for a setting, set a default one
  // this happens on a fresh install (or if you add a setting)
  // do not rely on the settingstile default value. that seems to only be visual

  if (Settings.getValue<double>('volume', -1) == -1) {
    await Settings.setValue<double>('volume', 4);
  }

  if (Settings.getValue<int>('start-sound', -1) == -1) {
    await Settings.setValue<int>('start-sound', 0);
  }

  if (Settings.getValue<int>('end-sound', -1) == -1) {
    await Settings.setValue<int>('end-sound', 1);
  }

  // if (Settings.getValue<bool>('hide-countdown', false) == false) {
  //   await Settings.setValue<bool>('hide-countdown', false);
  // }
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

  await initLogging();

  GetIt.I.registerSingleton<NAudioPlayer>(NAudioPlayer());

  await Settings.init();
  // await initFlutterBackground();
  await initNotifications();

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
      // theme: ThemeData.dark().copyWith(
      //   primaryColor: Colors.blue,
      // ),
      theme: ThemeData(
          colorScheme: ColorScheme.dark().copyWith(
            primary: Colors.indigoAccent[100],
            // primary: Colors.redAccent[100],
            // primary: Colors.deepPurpleAccent[100], // this seems to be close to the default
            background: Colors.black,
            surface: Colors.black,
            secondary: Colors.indigoAccent[100],
          ),
          scaffoldBackgroundColor: Color(0xFF121212),
          // scaffoldBackgroundColor: Colors.black,
          // scaffoldBackgroundColor: Colors.grey[900],
          typography: Typography.material2018(),
          backgroundColor: Colors.black,
          canvasColor: Colors.grey[900],
          dialogBackgroundColor: Colors.grey[900],
          progressIndicatorTheme: ProgressIndicatorThemeData(
            // circularTrackColor: Colors.black,
            circularTrackColor: Colors.grey[900],
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              primary: Colors.grey[300],
            ),
          ),

          // typography: Typography.white,
          // textTheme: Theme.of(context).textTheme.apply(
          //   fontSizeFactor: 1.5,
          // ),
          // textTheme: Theme.of(context).textTheme.copyWith(
          // textTheme: Typography().white.copyWith(
          //   bodyText2: Theme.of(context).textTheme.bodyText2?.copyWith(
          //     fontSize: 16,
          //     letterSpacing: 0.25,
          //     color: Colors.white,
          //   )
          // ),
          // textTheme: Theme.of(context).textTheme.copyWith(
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
                button: Typography().white.button?.copyWith(
                      // button: Theme.of(context).textTheme.button?.copyWith(
                      // fontSizeFactor: 1.2,
                      // fontWeightDelta: 2,
                      // letterSpacingDelta: 2,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
              )),
      // primaryColor: Colors.blue,
      // ),
      home: const Home(),
      // home: WithForegroundTask(
      //   child: const Home(),
      // ),
    );
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

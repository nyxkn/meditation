import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:meditation/audioplayer.dart';
import 'package:meditation/utils.dart';

const Map<String, String> audioFiles = {
  'bell_burma.ogg': 'Burma Bell',
  'bell_burma_three.ogg': 'Three Burma Bells',
  'bell_indian.ogg': 'Indian Bell',
  'bell_meditation.ogg': 'Meditation Bell',
  'bell_singing.ogg': 'Singing Bell',
  // 'bell_zen.ogg': 'Zen Bell',
  'bowl_singing.ogg': 'Singing Bowl',
  'bowl_singing_big.ogg': 'Big Singing Bowl',
  // 'bowl_tibetan.ogg': 'Tibetan Bowl',
  'gong_bodhi.ogg': 'Gong',
  'gong_generated.ogg': 'Generated Gong',
  // 'gong_metal.ogg': 'Metal Gong',
  'gong_watts.ogg': 'Alan Watts Gong',
};

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({Key? key}) : super(key: key);

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  @override
  Widget build(BuildContext context) {
    Map<int, String> soundsValues = {};
    for (var i = 0; i < audioFiles.length; i++) {
      soundsValues[i] = audioFiles.values.elementAt(i);
    }

    final GetIt getIt = GetIt.instance;
    final NAudioPlayer audioPlayer = getIt.get<NAudioPlayer>();
    double lastVolumeValue = -1;
    int lastStartSoundValue = -1;
    int lastEndSoundValue = -1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        // child: Column(
        child: ListView(
          // mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsGroup(
              title: 'volume',
              children: [
                SliderSettingsTile(
                  title: 'Bells volume',
                  settingKey: 'volume',
                  min: 0,
                  max: 10,
                  step: 1,
                  leading: Icon(Icons.volume_up),
                  onChange: (value) {
                    if (value != lastVolumeValue) {
                      audioPlayer.playSound('end-sound');
                    }
                    lastVolumeValue = value;
                  },
                ),
              ],
            ),
            SettingsGroup(
              title: 'Options',
              children: <Widget>[
                // CheckboxSettingsTile(title: 'Hide timer countdown', settingKey: 'hide-countdown'),
                CheckboxSettingsTile(
                  title: 'Keep screen on',
                  settingKey: 'screen-wakelock',
                  subtitle: "Enable this to keep the screen on as you meditate",
                ),
                CheckboxSettingsTile(
                  title: 'Do not disturb',
                  settingKey: 'dnd',
                  subtitle: "Enable 'Do Not Disturb' mode while meditating",
                  onChange: (value) async {
                    if (value == true) {
                      if (!(await FlutterDnd.isNotificationPolicyAccessGranted ?? false)) {
                        askPermissionDND();
                      }
                    }
                  },
                ),
                CheckboxSettingsTile(
                  title: 'Show countdown',
                  settingKey: 'show-countdown',
                  subtitle: "Show the remaining meditation time",
                ),
                TextInputSettingsTile(
                  title: 'Start delay',
                  settingKey: 'delay-time',
                  keyboardType: TextInputType.number,
                  selectAllOnFocus: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: timeInputValidatorConstructor(minTimerTime: 0, maxTimerTime: 60) as Validator,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  borderColor: primaryColor,
                  errorColor: secondaryColor,
                  helperText: 'Delay time in seconds, between 1 and 60. Use 0 to disable.',
                ),
              ],
            ),
            SettingsGroup(
              title: 'Sounds',
              children: <Widget>[
                RadioModalSettingsTile<int>(
                  title: 'Start sound',
                  settingKey: 'start-sound',
                  selected: soundsValues.keys.first,
                  values: soundsValues,
                  onChange: (value) {
                    if (value != lastStartSoundValue) {
                      audioPlayer.play(audioFiles.keys.elementAt(value));
                    }
                    lastStartSoundValue = value;
                  },
                ),
                RadioModalSettingsTile<int>(
                  title: 'End sound',
                  settingKey: 'end-sound',
                  selected: soundsValues.keys.elementAt(1),
                  values: soundsValues,
                  onChange: (value) {
                    if (value != lastEndSoundValue) {
                      audioPlayer.play(audioFiles.keys.elementAt(value));
                    }
                    lastEndSoundValue = value;
                  },
                ),
              ],
            ),
            SettingsGroup(
              title: 'Intervals',
              children: [
                CheckboxSettingsTile(
                  settingKey: 'intervals-enabled',
                  title: 'Enable intervals',
                  subtitle: 'Intermediate bells during your meditation',
                  childrenIfEnabled: [
                    Divider(height: 4, thickness: 4, indent: 0),
                    Container(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Column(
                        children: [
                          TextInputSettingsTile(
                            title: 'Interval duration',
                            settingKey: 'interval-time',
                            keyboardType: TextInputType.number,
                            selectAllOnFocus: true,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: timeInputValidatorConstructor(minTimerTime: 1, maxTimerTime: maxMeditationTime) as Validator,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              FilteringTextInputFormatter.deny(RegExp(r"^0")),
                            ],
                            borderColor: primaryColor,
                            errorColor: secondaryColor,
                            helperText: 'Interval time in minutes, between 1 and $maxMeditationTime.',
                          ),
                          // Divider(
                          //   height: 1,
                          //   thickness: 1,
                          //   indent: 8,
                          // ),
                          RadioModalSettingsTile<int>(
                            title: 'Interval sound',
                            settingKey: 'interval-sound',
                            selected: soundsValues.keys.first,
                            values: soundsValues,
                            onChange: (value) {
                              if (value != lastStartSoundValue) {
                                audioPlayer.play(audioFiles.keys.elementAt(value));
                              }
                              lastStartSoundValue = value;
                            },
                          ),
                          SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SettingsGroup(
              title: 'Info',
              children: [
                SizedBox(height: 16),
                SimpleSettingsTile(
                  title: 'About',
                  subtitle: 'Licences and other information',
                  onTap: () async {
                    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
                    showAboutDialog(
                      context: context,
                      applicationName: packageInfo.appName,
                      applicationVersion: packageInfo.version + ' (${packageInfo.buildNumber})',
                      applicationLegalese:
                          "${packageInfo.packageName}\n\nA meditation timer made with Flutter.",
                    );
                  },
                ),
              ],
            ),
            if (!kReleaseMode)
              SettingsGroup(
                title: 'Debug',
                children: [],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> askPermissionDND() async {
    bool hasPermissions = await FlutterDnd.isNotificationPolicyAccessGranted ?? false;
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
                    "You'll now be taken to your system settings where you can grant this app the permission to access Do Not Disturb settings.\n"),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () async {
                Navigator.of(context).pop();
                // this function simply opens the settings, but the following code runs immediately in parallel
                // so we can't run code after we return to the app from changing the settings
                FlutterDnd.gotoPolicySettings();
                // this runs while we're in the settings screen
                // so our only option is to set false regardless and have the user re-check the setting
                await Settings.setValue<bool>('dnd', false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsWidget()),
                );
              },
            ),
          ],
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:meditation/audioplayer.dart';

const Map<String, String> audioFiles = {
  'bell_burma.ogg': 'Burma Bell',
  'bell_burma_three.ogg': 'Three Burma Bells',
  'bell_indian.ogg': 'Indian Bell',
  'bell_meditation.ogg': 'Meditation Bell',
  'bell_singing.ogg': 'Singing Bell',
  'bell_zen.ogg': 'Zen Bell',
  'bowl_singing.ogg': 'Singing Bowl',
  'bowl_singing_big.ogg': 'Big Singing Bowl',
  'bowl_tibetan.ogg': 'Tibetan Bowl',
  'gong_bodhi.ogg': 'Gong',
  'gong_generated.ogg': 'Generated Gong',
  'gong_metal.ogg': 'Metal Gong',
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
              ],
            ),
            SettingsGroup(
              title: 'Sounds',
              children: <Widget>[
                SizedBox(height: 16),
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
                SizedBox(height: 20),
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
              title: 'info',
              children: [
                SizedBox(height: 16),
                SimpleSettingsTile(
                  title: 'About',
                  subtitle: 'More info and licences',
                  onTap: () async {
                    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
                    showAboutDialog(
                      context: context,
                      applicationName: packageInfo.appName,
                      applicationVersion: packageInfo.version + ' (${packageInfo.buildNumber})',
                      applicationLegalese: "${packageInfo.packageName}\n\nA meditation timer made with Flutter.",
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

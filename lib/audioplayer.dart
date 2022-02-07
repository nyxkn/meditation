import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:volume_controller/volume_controller.dart';

import 'package:meditation/settings.dart';
import 'package:meditation/utils.dart';

class NAudioPlayer {
  final audioPlayer = AudioCache();
  AudioPlayer lastAudioPlayer = AudioPlayer();
  double lastSystemVolume = 0;
  bool volumeHijackable = true;

  NAudioPlayer() {
    init();
  }

  void init() {
    log("naudioplayer", "init");
    // can only hide on android
    VolumeController().showSystemUI = false;
    audioPlayer.loadAll(audioFiles.keys.toList());
  }

  Future<void> play(String audioFile) async {
    // await lastAudioPlayer.stop();
    stopPrevious();
    hijackVolume();
    lastAudioPlayer = await audioPlayer.play(audioFile, volume: 1.0);
    // restore volume when audio is done playing
    lastAudioPlayer.onPlayerCompletion.listen((event) {
      restoreVolume();
    });
  }

  Future<int> stopPrevious() async {
    int result = await lastAudioPlayer.stop();
    return result;
  }

  Future<void> playSound(String soundKey) async {
    int audioIndex = Settings.getValue<int>(soundKey, 0);
    String audioFile = audioFiles.keys.elementAt(audioIndex);
    await play(audioFile);
  }

  void hijackVolume() async {
    if (volumeHijackable) {
      lastSystemVolume = await VolumeController().getVolume();
      volumeHijackable = false;
    }
    double volume = Settings.getValue<double>('volume', 1) / 10.0;
    VolumeController().setVolume(volume);
  }

  void restoreVolume() {
    VolumeController().setVolume(lastSystemVolume);
    volumeHijackable = true;
  }
}
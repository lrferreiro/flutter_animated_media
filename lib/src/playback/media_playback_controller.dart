import 'package:flutter/foundation.dart';

/// Optional shared playback intent. Each view retains its own playhead.
final class MediaPlaybackController extends ChangeNotifier {
  MediaPlaybackController({bool playing = true}) : _playing = playing;

  bool _playing;
  int _replay = 0;
  bool get isPlaying => _playing;
  int get replayRevision => _replay;

  void play() {
    if (_playing) return;
    _playing = true;
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
  }

  void replay() {
    _replay++;
    _playing = true;
    notifyListeners();
  }
}

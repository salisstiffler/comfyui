import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/task_model.dart';

enum LoopMode { off, single, all }

class PlaybackProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<AiTask> _playlist = [];
  int _currentIndex = -1;
  LoopMode _loopMode = LoopMode.off;
  double _playbackSpeed = 1.0;

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  PlaybackProvider() {
    _player.onPlayerStateChanged.listen((s) {
      _playerState = s;
      if (s == PlayerState.completed) {
        _handleTrackComplete();
      }
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
  }

  // Getters
  List<AiTask> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  AiTask? get currentTask =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
      ? _playlist[_currentIndex]
      : null;
  bool get isPlaying => _playerState == PlayerState.playing;
  Duration get duration => _duration;
  Duration get position => _position;
  double get playbackSpeed => _playbackSpeed;
  LoopMode get loopMode => _loopMode;
  PlayerState get playerState => _playerState;

  // Actions
  Future<void> setPlaylist(List<AiTask> tasks, {int initialIndex = 0}) async {
    _playlist = List.from(tasks);
    if (_playlist.isNotEmpty) {
      await playAtIndex(initialIndex);
    }
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    final task = _playlist[_currentIndex];
    if (task.resultAudioUrl != null) {
      await _player.stop();
      await _player.setPlaybackRate(_playbackSpeed);
      await _player.play(UrlSource(task.resultAudioUrl!));
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await _player.pause();
    } else {
      if (_currentIndex == -1 && _playlist.isNotEmpty) {
        await playAtIndex(0);
      } else {
        await _player.resume();
      }
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) {
      nextIndex = 0; // Loop back
    }
    await playAtIndex(nextIndex);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _playlist.length - 1;
    }
    await playAtIndex(prevIndex);
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void setSpeed(double speed) {
    _playbackSpeed = speed;
    _player.setPlaybackRate(speed);
    notifyListeners();
  }

  void setLoopMode(LoopMode mode) {
    _loopMode = mode;
    notifyListeners();
  }

  void toggleLoopMode() {
    _loopMode = LoopMode.values[(_loopMode.index + 1) % LoopMode.values.length];
    notifyListeners();
  }

  void _handleTrackComplete() {
    if (_loopMode == LoopMode.single) {
      playAtIndex(_currentIndex);
    } else if (_loopMode == LoopMode.all ||
        _currentIndex < _playlist.length - 1) {
      next();
    } else {
      _player.stop();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

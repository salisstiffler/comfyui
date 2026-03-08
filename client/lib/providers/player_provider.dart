import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import '../models/task_model.dart';

enum PlaybackMode { order, single, loop, shuffle }

class PlaybackProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  List<AiTask> _playlist = [];
  int _currentIndex = -1;
  PlaybackMode _mode = PlaybackMode.loop;
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
  PlaybackMode get mode => _mode;
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
    int nextIndex;

    if (_mode == PlaybackMode.shuffle) {
      nextIndex = _random.nextInt(_playlist.length);
      // Try to avoid playing the same track again if there are multiple
      if (nextIndex == _currentIndex && _playlist.length > 1) {
        nextIndex = (nextIndex + 1) % _playlist.length;
      }
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        nextIndex = 0; // Loop back
      }
    }
    await playAtIndex(nextIndex);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    int prevIndex;

    if (_mode == PlaybackMode.shuffle) {
      prevIndex = _random.nextInt(_playlist.length);
    } else {
      prevIndex = _currentIndex - 1;
      if (prevIndex < 0) {
        prevIndex = _playlist.length - 1;
      }
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

  void setPlaybackMode(PlaybackMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  void togglePlaybackMode() {
    _mode = PlaybackMode.values[(_mode.index + 1) % PlaybackMode.values.length];
    notifyListeners();
  }

  void _handleTrackComplete() {
    switch (_mode) {
      case PlaybackMode.single:
        playAtIndex(_currentIndex);
        break;
      case PlaybackMode.shuffle:
        next();
        break;
      case PlaybackMode.loop:
        next();
        break;
      case PlaybackMode.order:
        if (_currentIndex < _playlist.length - 1) {
          next();
        } else {
          _player.stop();
        }
        break;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

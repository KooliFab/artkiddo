import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../logging/log.dart';

abstract class AudioPlayerService {
  Future<void> setFilePath(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  Stream<bool> get isPlayingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<ProcessingState> get processingStateStream;

  Duration get position;
  Duration? get duration;
  bool get isPlaying;

  Future<void> dispose();
}

class JustAudioPlayerService implements AudioPlayerService {
  final AudioPlayer _player;
  bool _sessionConfigured = false;

  JustAudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _sessionConfigured = true;
    } catch (e, st) {
      Log.e('Configuration AudioSession impossible', e, st, 'AudioPlayer');
    }
  }

  @override
  Future<void> setFilePath(String filePath) async {
    await _ensureSession();
    await _player.setFilePath(filePath);
  }

  @override
  Future<void> play() async {
    await _ensureSession();
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<bool> get isPlayingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  bool get isPlaying => _player.playing;

  @override
  Future<void> dispose() => _player.dispose();
}

class FakeAudioPlayerService implements AudioPlayerService {
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<ProcessingState> _processingStateController =
      StreamController<ProcessingState>.broadcast();

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(seconds: 15);
  String? currentFilePath;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<bool> get isPlayingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;

  @override
  Future<void> setFilePath(String filePath) async {
    currentFilePath = filePath;
    _position = Duration.zero;
    _positionController.add(_position);
    _durationController.add(_duration);
    _processingStateController.add(ProcessingState.ready);
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _position = Duration.zero;
    _playingController.add(false);
    _positionController.add(_position);
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(_position);
  }

  void simulateCompletion() {
    _isPlaying = false;
    _position = _duration;
    _playingController.add(false);
    _positionController.add(_position);
    _processingStateController.add(ProcessingState.completed);
  }

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _processingStateController.close();
  }
}

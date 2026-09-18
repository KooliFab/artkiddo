import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import '../logging/log.dart';

/// Normative audio configuration for voice notes: AAC-LC mono, M4A
/// container, 44.1 kHz, 64 kbit/s. 2 minutes is approximately 1 MB.
abstract class AudioRecorderService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Starts recording audio directly into [targetPath].
  Future<void> startRecording({required String targetPath});

  /// Stops the current recording and returns the recorded duration in
  /// milliseconds, or null if no recording was in progress.
  Future<int?> stopRecording();

  /// Cancels and discards the recording, cleaning up the
  /// in-progress file if any.
  Future<void> cancelRecording();

  /// Normalised amplitude stream (0.0 to 1.0) for visual feedback.
  Stream<double> get amplitudeStream;

  /// Elapsed duration stream of the active recording.
  Stream<Duration> get durationStream;

  bool get isRecording;

  Future<void> dispose();
}

/// Real implementation using the `record` package.
class RecordAudioRecorderService implements AudioRecorderService {
  final AudioRecorder? _customRecorder;
  AudioRecorder? _recorder;
  bool _isDisposed = false;

  StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  Timer? _timer;
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _startedAt;
  bool _isRecording = false;

  RecordAudioRecorderService({AudioRecorder? recorder})
    : _customRecorder = recorder,
      _recorder = recorder;

  AudioRecorder _getRecorder() {
    if (_recorder == null || _isDisposed) {
      _recorder = _customRecorder ?? AudioRecorder();
      _isDisposed = false;
    }
    return _recorder!;
  }

  void _resetRecorder() {
    final old = _recorder;
    _recorder = null;
    if (old != null && old != _customRecorder) {
      try {
        old.dispose();
      } catch (_) {}
    }
  }

  Future<T> _runWithRecorder<T>(
    Future<T> Function(AudioRecorder recorder) action,
  ) async {
    try {
      return await action(_getRecorder());
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Recorder has not yet been created') ||
          msg.contains('already been disposed') ||
          msg.contains('PlatformException(record')) {
        Log.w(
          'Enregistreur natif indisponible ($msg), recréation...',
          'AudioRecorder',
        );
        _resetRecorder();
        return await action(_getRecorder());
      }
      rethrow;
    }
  }

  StreamController<double> get _activeAmpController {
    if (_amplitudeController.isClosed) {
      _amplitudeController = StreamController<double>.broadcast();
    }
    return _amplitudeController;
  }

  StreamController<Duration> get _activeDurController {
    if (_durationController.isClosed) {
      _durationController = StreamController<Duration>.broadcast();
    }
    return _durationController;
  }

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _activeAmpController.stream;

  @override
  Stream<Duration> get durationStream => _activeDurController.stream;

  @override
  Future<bool> hasPermission() =>
      _runWithRecorder((recorder) => recorder.hasPermission(request: false));

  @override
  Future<bool> requestPermission() =>
      _runWithRecorder((recorder) => recorder.hasPermission(request: true));

  @override
  Future<void> startRecording({required String targetPath}) async {
    if (_isRecording) {
      await cancelRecording();
    }

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 64000,
      numChannels: 1,
    );

    await _runWithRecorder(
      (recorder) => recorder.start(config, path: targetPath),
    );
    _isRecording = true;
    _startedAt = DateTime.now();

    // Stream amplitude every 100ms.
    _ampSub?.cancel();
    try {
      _ampSub = _getRecorder()
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
            (amp) {
              final db = amp.current;
              final normalized = ((db + 60.0) / 60.0).clamp(0.0, 1.0);
              if (!_activeAmpController.isClosed) {
                _activeAmpController.add(normalized);
              }
            },
            onError: (err) {
              Log.w('Amplitude stream error: $err', 'AudioRecorder');
            },
          );
    } catch (e) {
      Log.w('Impossible d’attacher le flux d’amplitude: $e', 'AudioRecorder');
    }

    // Duration timer every 100ms.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_startedAt != null && !_activeDurController.isClosed) {
        final elapsed = DateTime.now().difference(_startedAt!);
        _activeDurController.add(elapsed);
      }
    });
  }

  @override
  Future<int?> stopRecording() async {
    if (!_isRecording) return null;
    _timer?.cancel();
    _timer = null;
    await _ampSub?.cancel();
    _ampSub = null;

    final elapsedMs = _startedAt != null
        ? DateTime.now().difference(_startedAt!).inMilliseconds
        : null;

    try {
      final rec = _recorder;
      if (rec != null) {
        await rec.stop();
      }
    } catch (e, st) {
      Log.e('Erreur lors de l’arrêt de l’enregistreur', e, st, 'AudioRecorder');
    } finally {
      _isRecording = false;
      _startedAt = null;
    }

    return elapsedMs;
  }

  @override
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    await _ampSub?.cancel();
    _ampSub = null;
    _isRecording = false;
    _startedAt = null;

    try {
      final rec = _recorder;
      if (rec != null) {
        await rec.cancel();
      }
    } catch (e, st) {
      Log.e(
        'Erreur lors de l’annulation de l’enregistreur',
        e,
        st,
        'AudioRecorder',
      );
    }
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _ampSub?.cancel();
    _ampSub = null;
    _isRecording = false;
    _startedAt = null;
    await _amplitudeController.close();
    await _durationController.close();
    _resetRecorder();
    _isDisposed = true;
  }
}

/// Fake implementation for tests without native platform channels.
class FakeAudioRecorderService implements AudioRecorderService {
  bool permissionGranted = true;
  String? currentPath;
  DateTime? startedAt;
  bool _isRecording = false;
  int fakeRecordedDurationMs = 5000;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> startRecording({required String targetPath}) async {
    if (!permissionGranted) {
      throw StateError('Microphone permission denied');
    }
    _isRecording = true;
    currentPath = targetPath;
    startedAt = DateTime.now();

    // Create target file so it exists.
    final file = File(targetPath);
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsBytes(List.filled(1024, 0));
    }
  }

  void emitAmplitude(double amp) {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(amp);
    }
  }

  void emitDuration(Duration duration) {
    if (!_durationController.isClosed) {
      _durationController.add(duration);
    }
  }

  @override
  Future<int?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    return fakeRecordedDurationMs;
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
    if (currentPath != null) {
      final file = File(currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
      currentPath = null;
    }
  }

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
    await _durationController.close();
  }
}

part of 'artwork_screen.dart';

class _ArtworkAudioPlayerCard extends ConsumerStatefulWidget {
  final Artwork artwork;
  final VoidCallback onReRecord;
  final VoidCallback onDelete;

  const _ArtworkAudioPlayerCard({
    required this.artwork,
    required this.onReRecord,
    required this.onDelete,
  });

  @override
  ConsumerState<_ArtworkAudioPlayerCard> createState() =>
      _ArtworkAudioPlayerCardState();
}

class _ArtworkAudioPlayerCardState
    extends ConsumerState<_ArtworkAudioPlayerCard> {
  AudioPlayerService? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  bool _downloading = false;
  bool _downloadFailed = false;
  bool _isPlaying = false;
  int _positionMs = 0;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void didUpdateWidget(covariant _ArtworkAudioPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork.relativeAudioPath !=
        widget.artwork.relativeAudioPath) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    final m = widget.artwork;
    if (!m.isAudioLocal) {
      _downloadAudio();
      return;
    }

    try {
      final vault = ref.read(localVaultProvider);
      final file = await vault.resolveFile(m.relativeAudioPath!);
      if (!await file.exists()) {
        _downloadAudio();
        return;
      }
      _player = ref.read(audioPlayerServiceProvider);
      await _player!.setFilePath(file.path);

      _posSub?.cancel();
      _posSub = _player!.positionStream.listen((pos) {
        if (mounted) setState(() => _positionMs = pos.inMilliseconds);
      });

      _playSub?.cancel();
      _playSub = _player!.isPlayingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
    } catch (e, st) {
      Log.e('Failed to load audio file', e, st, 'ArtworkScreen');
    }
  }

  Future<void> _downloadAudio() async {
    setState(() {
      _downloading = true;
      _downloadFailed = false;
    });

    final fetcher = ref.read(remoteMediaFetcherProvider);
    final downloaded = await fetcher.ensureAudioDownloaded(widget.artwork.id);

    if (!mounted) return;

    if (downloaded) {
      setState(() => _downloading = false);
      final repo = ref.read(artworksRepositoryProvider);
      final updated = await repo.getById(widget.artwork.id);
      if (updated != null && mounted) {
        final vault = ref.read(localVaultProvider);
        if (updated.relativeAudioPath != null) {
          final file = await vault.resolveFile(updated.relativeAudioPath!);
          if (await file.exists()) {
            _player = ref.read(audioPlayerServiceProvider);
            await _player!.setFilePath(file.path);
            _posSub?.cancel();
            _posSub = _player!.positionStream.listen((pos) {
              if (mounted) setState(() => _positionMs = pos.inMilliseconds);
            });
            _playSub?.cancel();
            _playSub = _player!.isPlayingStream.listen((playing) {
              if (mounted) setState(() => _isPlaying = playing);
            });
          } else {
            if (mounted) {
              setState(() => _downloadFailed = true);
            }
          }
        }
      }
    } else {
      setState(() {
        _downloading = false;
        _downloadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_player == null) return;
    if (_isPlaying) {
      await _player!.pause();
    } else {
      final m = widget.artwork;
      if (m.relativeAudioPath != null) {
        try {
          final vault = ref.read(localVaultProvider);
          final file = await vault.resolveFile(m.relativeAudioPath!);
          if (await file.exists()) {
            final len = await file.length();
            Log.i(
              'Lecture audio pour œuvre ${m.id} : $len octets (${(len / 1024).toStringAsFixed(1)} Ko)',
              'ArtworkScreen',
            );
          }
        } catch (_) {}
      }
      await _player!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final durationMs = widget.artwork.audioDurationMs ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: AppColors.accent),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  l10n.artworkAudioCardTitle,
                  style: AppTypography.bodyStrong,
                ),
              ),
              if (durationMs > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    formatAudioDuration(durationMs),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPressed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          if (_downloading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.s3),
                Text(
                  l10n.artworkAudioDownloading,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ] else if (_downloadFailed) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.artworkAudioDownloadError,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                TextButton(
                  onPressed: _downloadAudio,
                  child: Text(l10n.artworkAudioRetry),
                ),
              ],
            ),
          ] else ...[
            AudioPlaybackRow(
              isPlaying: _isPlaying,
              positionMs: _positionMs,
              durationMs: durationMs,
              onToggle: _togglePlayback,
            ),
          ],
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s1,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.captureAudioReRecord),
                onPressed: widget.onReRecord,
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.captureAudioDelete),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioRecorderSheet extends ConsumerStatefulWidget {
  final String artworkId;
  const _AudioRecorderSheet({required this.artworkId});

  @override
  ConsumerState<_AudioRecorderSheet> createState() =>
      _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends ConsumerState<_AudioRecorderSheet> {
  static const _maxAudioDurationMs = 120000;

  late final AudioRecorderService _recorder;
  late final AudioPlayerService _player;
  StreamSubscription<double>? _ampSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;

  bool _isRecording = false;
  int _recordingDurationMs = 0;
  double _soundLevel = 0.0;

  String? _recordedPath;
  int? _recordedDurationMs;
  bool _isPlaying = false;
  int _playbackPositionMs = 0;
  bool _saving = false;
  bool _micDenied = false;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(audioRecorderServiceProvider);
    _player = ref.read(audioPlayerServiceProvider);
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _playSub?.cancel();
    if (_isRecording) {
      _recorder.cancelRecording();
    }
    _cleanTempFile();
    super.dispose();
  }

  void _cleanTempFile() {
    if (_recordedPath != null) {
      try {
        final f = File(_recordedPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    await _stopPlayback();

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        final granted = await _recorder.requestPermission();
        if (!granted) {
          if (mounted) setState(() => _micDenied = true);
          return;
        }
      }
    } catch (e, st) {
      Log.e('Error checking microphone permissions', e, st, 'ArtworkScreen');
      if (mounted) setState(() => _micDenied = true);
      return;
    }

    _cleanTempFile();
    final tempPath =
        '${Directory.systemTemp.path}/artkiddo_art_${widget.artworkId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordedPath = tempPath;

    setState(() {
      _isRecording = true;
      _recordingDurationMs = 0;
      _soundLevel = 0.0;
      _recordedDurationMs = null;
      _micDenied = false;
    });

    _ampSub?.cancel();
    _ampSub = _recorder.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _soundLevel = amp);
    });

    _durSub?.cancel();
    _durSub = _recorder.durationStream.listen((dur) {
      final ms = dur.inMilliseconds;
      if (ms >= _maxAudioDurationMs) {
        _stopRecording();
      } else {
        if (mounted) setState(() => _recordingDurationMs = ms);
      }
    });

    try {
      await _recorder.startRecording(targetPath: tempPath);
    } catch (e, st) {
      Log.e('Error starting audio recording', e, st, 'ArtworkScreen');
      _ampSub?.cancel();
      _durSub?.cancel();
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final durMs = await _recorder.stopRecording();
    _ampSub?.cancel();
    _durSub?.cancel();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _soundLevel = 0.0;
      _recordedDurationMs = (durMs ?? _recordingDurationMs)
          .clamp(1, _maxAudioDurationMs)
          .toInt();
    });

    if (_recordedPath != null) {
      await _player.setFilePath(_recordedPath!);
      _posSub?.cancel();
      _posSub = _player.positionStream.listen((pos) {
        if (mounted) setState(() => _playbackPositionMs = pos.inMilliseconds);
      });
      _playSub?.cancel();
      _playSub = _player.isPlayingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.cancelRecording();
    _ampSub?.cancel();
    _durSub?.cancel();
    _cleanTempFile();
    _recordedPath = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDurationMs = 0;
        _soundLevel = 0.0;
      });
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playbackPositionMs = 0;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordedPath == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _saveAudio() async {
    if (_recordedPath == null || _recordedDurationMs == null || _saving) return;
    setState(() => _saving = true);
    await _stopPlayback();

    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.updateAudio(
      id: widget.artworkId,
      sourceAudioFile: File(_recordedPath!),
      durationMs: _recordedDurationMs!,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result is ActionSuccess) {
      _cleanTempFile();
      Navigator.of(context).pop(true);
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkAudioSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // A take in progress or recorded but not saved is only thrown away
    // after the user confirms it.
    return DiscardGuard(
      isDirty: (_isRecording || _recordedPath != null) && !_saving,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s4,
            top: AppSpacing.s4,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.captureAudioCardTitle, style: AppTypography.h2),
                  IconButton(
                    tooltip: l10n.commonClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                l10n.captureAudioCardSubtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              if (_micDenied) ...[
                StateBlock(
                  intent: StateBlockIntent.warning,
                  title: l10n.captureAudioMicPermissionDeniedTitle,
                  body: l10n.captureAudioMicPermissionDeniedBody,
                  actionLabel: l10n.commonOpenSettings,
                  onAction: AppSettingsLauncher.open,
                ),
              ] else if (_isRecording) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: AudioRecordingPanel(
                    durationMs: _recordingDurationMs,
                    soundLevel: _soundLevel,
                    onCancel: _cancelRecording,
                    onStop: _stopRecording,
                  ),
                ),
              ] else if (_recordedPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Column(
                    children: [
                      AudioPlaybackRow(
                        isPlaying: _isPlaying,
                        positionMs: _playbackPositionMs,
                        durationMs: _recordedDurationMs ?? 0,
                        onToggle: _togglePlayback,
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(l10n.captureAudioReRecord),
                            onPressed: _startRecording,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                AppButton(
                  label: _saving ? l10n.commonSaving : l10n.commonSave,
                  fullWidth: true,
                  onPressed: _saving ? null : _saveAudio,
                ),
              ] else ...[
                AppButton(
                  label: l10n.captureAudioRecord,
                  icon: Icons.mic,
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _startRecording,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

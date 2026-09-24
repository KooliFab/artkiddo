part of 'artwork_screen.dart';

String _formatDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

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
                    _formatDuration(durationMs),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.artworkAudioDownloadError,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _downloadAudio,
                  child: Text(l10n.artworkAudioRetry),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                IconButton.filled(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayback,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: durationMs > 0
                              ? (_positionMs / durationMs).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: AppColors.surfaceSunken,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        '${_formatDuration(_positionMs)} / ${_formatDuration(durationMs)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s1,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.captureAudioReRecord),
                  onPressed: widget.onReRecord,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: Text(
                    l10n.captureAudioDelete,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ],
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

    return SafeArea(
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
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              l10n.captureAudioCardSubtitle,
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          l10n.captureAudioRecording,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatDuration(_recordingDurationMs)} / 02:00',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _soundLevel.clamp(0.05, 1.0),
                        backgroundColor: AppColors.surfaceSunken,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(l10n.captureAudioCancel),
                          onPressed: _cancelRecording,
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.stop, size: 18),
                          label: Text(l10n.captureAudioStop),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          onPressed: _stopRecording,
                        ),
                      ],
                    ),
                  ],
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
                    Row(
                      children: [
                        IconButton.filled(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: _togglePlayback,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onAccent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value:
                                      (_recordedDurationMs != null &&
                                          _recordedDurationMs! > 0)
                                      ? (_playbackPositionMs /
                                                _recordedDurationMs!)
                                            .clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor: AppColors.surfaceSunken,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.accent,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s1),
                              Text(
                                '${_formatDuration(_playbackPositionMs)} / ${_formatDuration(_recordedDurationMs ?? 0)}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
              FilledButton(
                onPressed: _saving ? null : _saveAudio,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                ),
                child: Text(_saving ? l10n.commonSaving : l10n.commonSave),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.mic, color: AppColors.accent),
                label: Text(
                  l10n.captureAudioRecord,
                  style: const TextStyle(color: AppColors.accent),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                ),
                onPressed: _startRecording,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

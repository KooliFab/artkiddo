import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../contracts/following.dart';
import '../../local/audio/audio_player_service.dart';
import '../../local/logging/log.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';
import '../ui/state_block.dart';
import 'audio_controls.dart';

/// Read-only view of an artwork from a followed household.
///
/// The artwork has no local row and no file: the image and the recording
/// come from temporary authorized URIs. Nothing here edits, deletes, records
/// or shares; those belong to the household that owns the artwork.
class FollowedArtworkScreen extends StatelessWidget {
  final FollowedArtwork artwork;

  const FollowedArtworkScreen({super.key, required this.artwork});

  static String heroTag(String artworkId) => 'followed-artwork-$artworkId';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = _FollowedImage(artwork: artwork);
    final panel = _panel(l10n);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!AppBreakpoints.isExpanded(constraints.maxWidth)) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    image,
                    const SizedBox(height: AppSpacing.s4),
                    ...panel,
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: image),
                  const SizedBox(width: AppSpacing.s5),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: panel,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _panel(AppLocalizations l10n) {
    final story = artwork.story;
    final hasStory = story != null && story.isNotEmpty;
    return [
      Text(artwork.childName, style: AppTypography.h1),
      const SizedBox(height: AppSpacing.s1),
      Text(
        followedFamilyLabel(l10n, artwork.familyName),
        style: AppTypography.body.copyWith(color: AppColors.inkMuted),
      ),
      const SizedBox(height: AppSpacing.s1),
      Text(
        artwork.drawnAt != null
            ? l10n.artworkDrawnOn(artwork.drawnAt!)
            : l10n.artworkAddedOn(artwork.addedAt),
        style: AppTypography.bodyStrong,
      ),
      const SizedBox(height: AppSpacing.s5),
      if (artwork.audioUri != null) ...[
        _FollowedAudioCard(
          uri: artwork.audioUri!,
          duration: artwork.audioDuration,
        ),
        const SizedBox(height: AppSpacing.s4),
      ],
      if (hasStory) ...[
        Text(l10n.artworkStoryHeading, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.s2),
        Text(
          '« $story »',
          style: AppTypography.bodyLarge.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    ];
  }
}

/// "Famille Anne", or a neutral label when the household has no name yet.
String followedFamilyLabel(AppLocalizations l10n, String? familyName) =>
    familyName == null || familyName.trim().isEmpty
    ? l10n.followedFamilyUnnamed
    : l10n.followedFamilyNamed(familyName);

class _FollowedImage extends StatelessWidget {
  final FollowedArtwork artwork;

  const _FollowedImage({required this.artwork});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uri = artwork.imageUri ?? artwork.thumbnailUri;
    final missing = Container(
      color: AppColors.surfaceSunken,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Center(
        child: StateBlock(
          intent: StateBlockIntent.error,
          title: l10n.artworkImageMissingTitle,
          body: l10n.followedArtworkImageUnavailable,
        ),
      ),
    );
    return Hero(
      tag: FollowedArtworkScreen.heroTag(artwork.id),
      child: Semantics(
        image: true,
        label: l10n.a11yArtworkImage(artwork.childName, artwork.addedAt),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.artwork),
            child: uri == null
                ? missing
                : InteractiveViewer(
                    child: Container(
                      color: AppColors.surfaceSunken,
                      child: Image.network(
                        uri.toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => missing,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FollowedAudioCard extends ConsumerStatefulWidget {
  final Uri uri;
  final Duration? duration;

  const _FollowedAudioCard({required this.uri, required this.duration});

  @override
  ConsumerState<_FollowedAudioCard> createState() => _FollowedAudioCardState();
}

class _FollowedAudioCardState extends ConsumerState<_FollowedAudioCard> {
  AudioPlayerService? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  bool _loading = true;
  bool _failed = false;
  bool _isPlaying = false;
  int _positionMs = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final player = ref.read(audioPlayerServiceProvider);
      await player.setUrl(widget.uri);
      _posSub?.cancel();
      _posSub = player.positionStream.listen((pos) {
        if (mounted) setState(() => _positionMs = pos.inMilliseconds);
      });
      _playSub?.cancel();
      _playSub = player.isPlayingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
      _player = player;
      if (mounted) setState(() => _loading = false);
    } catch (e, st) {
      Log.e('Followed audio failed to load', e, st, 'FollowedArtwork');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _player?.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final durationMs = widget.duration?.inMilliseconds ?? 0;
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
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          if (_loading)
            Text(
              l10n.artworkAudioDownloading,
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            )
          else if (_failed) ...[
            Text(
              l10n.artworkAudioDownloadError,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
            TextButton(onPressed: _load, child: Text(l10n.artworkAudioRetry)),
          ] else
            AudioPlaybackRow(
              isPlaying: _isPlaying,
              positionMs: _positionMs,
              durationMs: durationMs,
              onToggle: _toggle,
            ),
        ],
      ),
    );
  }
}

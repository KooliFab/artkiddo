import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../domain/action_result.dart';
import '../../domain/child.dart';
import '../../domain/artwork.dart';
import '../../local/audio/audio_player_service.dart';
import '../../local/audio/audio_recorder_service.dart';
import '../../local/logging/log.dart';
import '../async_action.dart';
import '../children/children_providers.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../ui/discard_guard.dart';
import '../ui/error_presenter.dart';
import '../ui/formatters.dart';
import '../ui/state_block.dart';
import '../utils/app_settings_launcher.dart';
import 'artwork_zoom_screen.dart';
import '../navigation/composition_actions.dart';
import '../family/family_controller.dart';
import 'gallery_providers.dart';

/// `artwork` — `screens.md` §5.
class ArtworkScreen extends ConsumerStatefulWidget {
  final String artworkId;

  /// Data and image already present in the gallery tile. Passing these keeps
  /// the destination Hero mounted from the very first push frame.
  final Artwork? initialArtwork;
  final File? initialHeroFile;

  const ArtworkScreen({
    super.key,
    required this.artworkId,
    this.initialArtwork,
    this.initialHeroFile,
  });

  @override
  ConsumerState<ArtworkScreen> createState() => _ArtworkScreenState();
}

class _ArtworkScreenState extends ConsumerState<ArtworkScreen> {
  Artwork? _artwork;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _artwork = widget.initialArtwork;
    _loading = widget.initialArtwork == null;
    Log.d('📱 [ArtworkScreen] Opening (${widget.artworkId})', 'Navigation');
    if (ref.read(appCapabilitiesProvider).household) {
      // Attribution must be available even when the user opens an artwork
      // directly from the gallery without visiting the Family screen first.
      // Deferred past the first frame: the load flips the controller to busy
      // synchronously, which Riverpod forbids while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(familyControllerProvider.notifier).loadFamilyMembers(),
        );
      });
    }
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(artworksRepositoryProvider);
    final m = await repo.getById(widget.artworkId);
    if (!mounted) return;
    setState(() {
      _artwork = m;
      _loading = false;
    });
  }

  Future<void> _sendImage(Child? child, AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null) return;
    // C-06: share the highest fidelity actually on this device — the
    // untouched original when there is one, otherwise whatever derivative
    // was downloaded (a converged row never had an original here at all,
    // ADR 0007).
    final sharePath = m.relativeImagePath ?? m.bestDisplayImagePath;
    if (sharePath == null) return;
    final vault = ref.read(localVaultProvider);
    final file = await vault.resolveFile(sharePath);
    if (!await file.exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: child != null ? l10n.artworkShareText(child.name, m.addedAt) : '',
      ),
    );
  }

  Future<void> _editStory(AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _StoryEditorSheet(artworkId: m.id, initialStory: m.story ?? ''),
    );
    if (result != null && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkStorySaved)));
    }
  }

  Future<void> _clearAudio(AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null || !m.hasAudio) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.captureAudioDeleteConfirmTitle),
        content: Text(l10n.captureAudioDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.clearAudio(m.id);
    if (!mounted) return;
    if (result is ActionSuccess) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.captureAudioDelete)));
    }
  }

  Future<void> _recordAudio(AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null) return;
    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AudioRecorderSheet(artworkId: m.id),
    );
    if (recorded == true && mounted) {
      await _load();
    }
  }

  /// A-02: `drawnAt` is entered only from this screen, never at capture.
  /// The date picker's own `firstDate`/`lastDate` already rule out a
  /// future date or one before the child's birth when a child is known;
  /// the explicit checks below are defense in depth for the rarer case
  /// (no child, or birth date changed since the dialog opened) rather than
  /// silently accepting a nonsensical date.
  Future<void> _editDrawnAt(AppLocalizations l10n, Child? child) async {
    final m = _artwork;
    if (m == null) return;
    final now = DateTime.now();
    final firstDate = child?.birthDate ?? DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          m.drawnAt ??
          (child != null && !child.birthDate.isAfter(now)
              ? child.birthDate
              : now),
      firstDate: firstDate,
      lastDate: now,
      helpText: l10n.artworkDrawnAtPickerTitle,
    );
    if (picked == null || !mounted) return;

    if (picked.isAfter(now)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDrawnAtFutureError)));
      return;
    }
    if (child != null && picked.isBefore(child.birthDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.artworkDrawnAtBeforeBirthError)),
      );
      return;
    }

    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.updateDrawnAt(id: m.id, drawnAt: picked);
    if (!mounted) return;
    if (result is ActionSuccess) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDrawnAtSaved)));
    } else if (result is ActionFailed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDrawnAtError)));
    }
  }

  /// A-02: a cleared `drawnAt` must genuinely fall back to `addedAt` for
  /// the age calculation — same rigour as `_clearStory`.
  Future<void> _clearDrawnAt(AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.artworkDrawnAtClearConfirmTitle),
        content: Text(l10n.artworkDrawnAtClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDiscard),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.updateDrawnAt(id: m.id, drawnAt: null);
    if (!mounted) return;
    if (result is ActionSuccess) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDrawnAtCleared)));
    } else if (result is ActionFailed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDrawnAtError)));
    }
  }

  Future<void> _handleCalendarTap(AppLocalizations l10n, Child? child) async {
    final m = _artwork;
    if (m == null) return;
    if (m.drawnAt != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s3,
              AppSpacing.s5,
              AppSpacing.s6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.artworkDrawnAtPickerTitle, style: AppTypography.h2),
                const SizedBox(height: AppSpacing.s2),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: Text(l10n.artworkDrawnAtEdit),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(sheetContext).pop('edit'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_busy_outlined,
                    color: AppColors.danger,
                  ),
                  title: Text(
                    l10n.artworkDrawnAtClear,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(sheetContext).pop('clear'),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (choice == 'edit') {
        await _editDrawnAt(l10n, child);
      } else if (choice == 'clear') {
        await _clearDrawnAt(l10n);
      }
    } else {
      await _editDrawnAt(l10n, child);
    }
  }

  Future<void> _handleAudioTap(AppLocalizations l10n) async {
    final m = _artwork;
    if (m == null) return;
    if (m.hasAudio) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          title: Text(l10n.captureAudioReRecordConfirmTitle),
          content: Text(l10n.captureAudioReRecordConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.captureAudioReRecord),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _recordAudio(l10n);
  }

  Future<void> _showShareOptions(
    BuildContext context,
    Artwork m,
    Child? child,
    String childName,
    AppLocalizations l10n,
  ) async {
    final compositionActions = ref.read(compositionActionsProvider);
    final openShare = compositionActions.openGalleryShare;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s3,
            AppSpacing.s5,
            AppSpacing.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.childrenActionsShare, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s3),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined, color: AppColors.ink),
                title: Text(
                  l10n.artworkSendImage,
                  style: AppTypography.bodyStrong,
                ),
                subtitle: Text(
                  l10n.artworkSendImageHelp,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _sendImage(child, l10n);
                },
              ),
              if (ref.read(appCapabilitiesProvider).webGalleryLinks &&
                  openShare != null) ...[
                const SizedBox(height: AppSpacing.s2),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_rounded, color: AppColors.ink),
                  title: Text(
                    l10n.artworkShareGallery,
                    style: AppTypography.bodyStrong,
                  ),
                  subtitle: Text(
                    l10n.artworkShareGalleryHelp,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openShare(context, m.childId, childName);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AppLocalizations l10n, bool hasSyncedCopy) async {
    // D18: the dialog now owns the delete call itself — it used to close
    // (`Navigator.pop(true)`) the instant "Supprimer" was tapped, *before*
    // the repository call, so `deleting` (busy button, non-dismissible
    // dialog) never existed and a failure had nowhere to render.
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteArtworkDialog(
        artworkId: widget.artworkId,
        hasSyncedCopy: hasSyncedCopy,
      ),
    );
    if (deleted == true && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.artworkDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final m = _artwork;
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: StateBlock(
            intent: StateBlockIntent.error,
            title: l10n.errorNotFoundTitle,
            body: l10n.errorNotFoundBody,
            actionLabel: l10n.commonClose,
            onAction: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final childrenAsync = ref.watch(allChildrenStreamProvider);
    final children = childrenAsync.value ?? const <Child>[];
    final child = children.where((c) => c.id == m.childId).firstOrNull;
    final childName = child?.name ?? l10n.artworkUnknownArtist;

    final familyMembersMap = ref.watch(familyMembersMapProvider);
    final authorName = m.addedBy != null
        ? familyMembersMap[m.addedBy]?.displayName
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(childName, style: AppTypography.h3)),
      body: Stack(
        children: [
          // D32 (`navigation.md` §6): image + panel stack vertically at
          // compact, and sit side by side (60/40, panel capped at 400) at
          // medium/expanded, scrolling together.
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = !AppBreakpoints.isCompact(constraints.maxWidth);
                  final image = _buildImage(
                    context,
                    l10n,
                    m,
                    childName,
                    wide: wide,
                  );
                  final panel = _buildPanel(
                    context,
                    l10n,
                    m,
                    child,
                    childName,
                    authorName: authorName,
                  );

                  if (!wide) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s4,
                        120,
                      ),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s4,
                      AppSpacing.s4,
                      AppSpacing.s4,
                      120,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: image),
                        const SizedBox(width: AppSpacing.s5),
                        Expanded(
                          flex: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: panel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Floating action buttons with top-to-bottom gradient overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.paper.withValues(alpha: 0.0),
                    AppColors.paper.withValues(alpha: 0.85),
                    AppColors.paper,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s6,
                    AppSpacing.s4,
                    AppSpacing.s3,
                  ),
                  child: Center(
                    heightFactor: 1.0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Row(
                        children: [
                          _buildFloatingButton(
                            icon: Icons.mic_none_rounded,
                            color: AppColors.share,
                            tooltip: m.hasAudio
                                ? l10n.captureAudioReRecord
                                : l10n.captureAudioCardTitle,
                            onPressed: () => _handleAudioTap(l10n),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          _buildFloatingButton(
                            icon: Icons.edit_outlined,
                            color: AppColors.share,
                            tooltip: m.story != null && m.story!.isNotEmpty
                                ? l10n.artworkStoryEdit
                                : l10n.artworkStoryEmpty,
                            onPressed: () => _editStory(l10n),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          _buildFloatingButton(
                            icon: Icons.ios_share_rounded,
                            color: AppColors.share,
                            tooltip: l10n.childrenActionsShare,
                            onPressed: () => _showShareOptions(
                              context,
                              m,
                              child,
                              childName,
                              l10n,
                            ),
                          ),
                          const Spacer(),
                          _buildFloatingButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.danger,
                            tooltip: l10n.artworkDelete,
                            onPressed: () => _confirmDelete(
                              l10n,
                              m.syncState.name == 'synced',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Icon(icon, color: AppColors.onAccent, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    AppLocalizations l10n,
    Artwork m,
    String childName, {
    required bool wide,
  }) {
    return Hero(
      tag: 'artwork-${m.id}',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ArtworkZoomScreen(artworkId: m.id, childName: childName),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (wide ? 0.75 : 0.6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.artwork),
            child: FutureBuilder<File>(
              // A-03/C-06: the detail screen reads the `display` derivative
              // (bounded to 1600px), falling back to the untouched original
              // when none has been generated yet, or to the thumbnail for a
              // freshly-converged row (D10). `null` (nothing downloaded at
              // all yet) resolves to a deliberately-absent path, reusing the
              // existing "missing image" branch below instead of a bespoke
              // loading state.
              future: m.bestDisplayImagePath != null
                  ? ref
                        .read(localVaultProvider)
                        .resolveFile(m.bestDisplayImagePath!)
                  : Future.value(File('')),
              // The gallery thumbnail is immediately available on the push.
              // It is swapped for the display derivative once that future
              // resolves, but it prevents a placeholder Hero on push.
              initialData: widget.initialHeroFile,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) {
                  return Container(color: AppColors.surfaceSunken, height: 240);
                }
                if (!file.existsSync()) {
                  return Container(
                    color: AppColors.surfaceSunken,
                    height: 240,
                    child: Center(
                      child: StateBlock(
                        intent: StateBlockIntent.error,
                        title: l10n.artworkImageMissingTitle,
                        body: l10n.artworkImageMissingBody,
                      ),
                    ),
                  );
                }
                return Container(
                  color: AppColors.surfaceSunken,
                  child: Image.file(file, fit: BoxFit.contain),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPanel(
    BuildContext context,
    AppLocalizations l10n,
    Artwork m,
    Child? child,
    String childName, {
    String? authorName,
  }) {
    // A-02: the age is computed on `drawnAt` when known, on `addedAt`
    // otherwise (CONTEXT.md rule 3) — `ageBasis` says which one so the
    // label ("Âge lors du dessin" vs "Âge lors de l'ajout") always matches
    // the figure actually shown, never confusing the two.
    final ageBasis = Formatters.ageBasis(drawnAt: m.drawnAt);
    final ageText = child != null
        ? Formatters.age(
            l10n,
            birthDate: child.birthDate,
            addedAt: m.addedAt,
            drawnAt: m.drawnAt,
          )
        : null;
    final ageLabel = ageText == null
        ? null
        : (ageBasis == AgeBasis.drawnAt
              ? l10n.artworkAgeAtDrawing(ageText)
              : l10n.artworkAgeAtAddition(ageText));

    return [
      Text(childName, style: AppTypography.h1),
      const SizedBox(height: AppSpacing.s1),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              m.drawnAt != null
                  ? l10n.artworkDrawnOn(m.drawnAt!)
                  : l10n.artworkAddedOn(m.addedAt),
              style: AppTypography.bodyStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.s1),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            color: AppColors.inkMuted,
            padding: const EdgeInsets.all(AppSpacing.s1),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: l10n.artworkDrawnAtEdit,
            onPressed: () => _handleCalendarTap(l10n, child),
          ),
        ],
      ),
      if (authorName != null && authorName.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.artworkAddedBy(authorName),
          style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
        ),
      ],
      if (ageLabel != null) ...[
        const SizedBox(height: AppSpacing.s1),
        Text(
          ageLabel,
          style: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
      ],
      const SizedBox(height: AppSpacing.s5),
      if (m.hasAudio) ...[
        _ArtworkAudioPlayerCard(
          artwork: m,
          onReRecord: () => _recordAudio(l10n),
          onDelete: () => _clearAudio(l10n),
        ),
        const SizedBox(height: AppSpacing.s4),
      ],
      Text(l10n.artworkStoryHeading, style: AppTypography.h3),
      const SizedBox(height: AppSpacing.s2),
      Text(
        m.story != null && m.story!.isNotEmpty
            ? '« ${m.story} »'
            : l10n.artworkStoryEmpty,
        style: AppTypography.bodyLarge.copyWith(
          color: m.story != null ? AppColors.ink : AppColors.inkMuted,
          fontStyle: m.story != null ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      const SizedBox(height: AppSpacing.s4),
    ];
  }
}

class _StoryEditorSheet extends ConsumerStatefulWidget {
  final String artworkId;
  final String initialStory;
  const _StoryEditorSheet({
    required this.artworkId,
    required this.initialStory,
  });

  @override
  ConsumerState<_StoryEditorSheet> createState() => _StoryEditorSheetState();
}

class _StoryEditorSheetState extends ConsumerState<_StoryEditorSheet> {
  late final TextEditingController _controller;
  AsyncAction _save = const ActionIdle();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialStory);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty => _controller.text.trim() != widget.initialStory.trim();

  Future<void> _save0() async {
    // D45: isBusy guard to prevent duplicate saves while in-flight.
    if (_save.isBusy) return;
    setState(() => _save = const ActionBusy());
    final repo = ref.read(artworksRepositoryProvider);
    final text = _controller.text.trim();
    final result = await repo.updateStory(
      id: widget.artworkId,
      story: text.isEmpty ? null : text,
    );
    if (!mounted) return;
    if (result is ActionSuccess) {
      Navigator.of(context).pop(text);
    } else if (result is ActionFailed<void>) {
      setState(() => _save = ActionError(result.failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscardGuard(
      isDirty: _isDirty && !_save.isBusy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s6,
            right: AppSpacing.s6,
            top: AppSpacing.s4,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.artworkStoryEdit, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s3),
              if (_save case ActionError())
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: StateBlock(
                    intent: StateBlockIntent.error,
                    title: l10n.artworkStoryError,
                  ),
                ),
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 3,
                maxLength: 500,
                autofocus: true,
                enabled: !_save.isBusy,
                decoration: InputDecoration(hintText: l10n.artworkStoryHint),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: _save.isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AsyncActionButton(
                      action: _save,
                      idleLabel: l10n.commonSave,
                      busyLabel: l10n.commonSaving,
                      onPressed: _save0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D18: `screens.md` §5 `deleting`/`deleteError` — the dialog stays open
/// (non-dismissible) with a `busy` button while the repository call is in
/// flight, and only pops `true` once the deletion is actually confirmed.
/// A failure keeps the dialog open with a retryable error block, exactly
/// like `_DeleteChildDialog` / `_RevokeDialog`.
class _DeleteArtworkDialog extends ConsumerStatefulWidget {
  final String artworkId;
  final bool hasSyncedCopy;
  const _DeleteArtworkDialog({
    required this.artworkId,
    required this.hasSyncedCopy,
  });

  @override
  ConsumerState<_DeleteArtworkDialog> createState() =>
      _DeleteArtworkDialogState();
}

class _DeleteArtworkDialogState extends ConsumerState<_DeleteArtworkDialog> {
  AsyncAction _state = const ActionIdle();

  Future<void> _delete() async {
    if (_state.isBusy) return;
    setState(() => _state = const ActionBusy());
    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.delete(widget.artworkId);
    if (!mounted) return;
    switch (result) {
      case ActionSuccess():
        Navigator.of(context).pop(true);
      case ActionFailed(failure: final f):
        setState(() => _state = ActionError(f));
      case ActionCancelled():
        setState(() => _state = const ActionIdle());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _state.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.artworkDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.artworkDeleteBody),
            if (widget.hasSyncedCopy) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                l10n.artworkDeleteCloudNotice,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
            if (_state case ActionError(failure: final f)) ...[
              const SizedBox(height: AppSpacing.s3),
              StateBlock(
                intent: ErrorPresenter.intentFor(f),
                title: l10n.artworkDeleteError,
                actionLabel: l10n.commonRetry,
                onAction: _delete,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: busy ? null : _delete,
            child: Text(busy ? l10n.commonDeleting : l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

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

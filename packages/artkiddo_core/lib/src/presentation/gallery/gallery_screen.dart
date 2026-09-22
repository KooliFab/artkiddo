import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../domain/action_result.dart';
import '../../domain/child.dart';
import '../../local/logging/log.dart';
import '../../local/storage/vault_rescue_export.dart';
import '../children/child_editor_controller.dart';
import '../children/child_editor_screen.dart';
import '../children/children_providers.dart';
import '../children/children_screen.dart';
import '../config/app_capabilities.dart';
import '../providers/core_providers.dart';
import '../settings/settings_screen.dart';
import '../theme/app_tokens.dart';
import '../ui/filter_chip_row.dart';
import '../ui/state_block.dart';
import 'artwork_screen.dart';
import 'capture_controller.dart';
import 'capture_screen.dart';
import '../navigation/composition_actions.dart';
import 'gallery_providers.dart';

/// ArtKiddo's product surface: a calm, chronological wall of artwork.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    _scrollController.addListener(_saveScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_saveScroll)
      ..dispose();
    super.dispose();
  }

  void _saveScroll() {
    final filter = ref.read(galleryFilterProvider);
    ref
        .read(galleryScrollOffsetsProvider)
        .write(filter.scrollKey, _scrollController.offset);
  }

  void _restoreScroll() {
    if (!_scrollController.hasClients) return;
    final filter = ref.read(galleryFilterProvider);
    final offset = ref
        .read(galleryScrollOffsetsProvider)
        .read(filter.scrollKey);
    if (offset > 0 && offset <= _scrollController.position.maxScrollExtent) {
      _scrollController.jumpTo(offset);
    }
  }

  Future<void> _openCapture(BuildContext context, {String? childId}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const _CaptureSourceSheet(),
    );
    if (source == null || !context.mounted) return;
    final result = await Navigator.of(context).push<ActionResult<String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CaptureScreen(
          entry: CaptureEntry(
            preselectedChildId: childId,
            origin: CaptureOrigin.galleryFab,
          ),
          initialSource: source,
        ),
      ),
    );
    if (!context.mounted || result is! ActionSuccess<String>) return;
    _scrollController.animateTo(
      0,
      duration: AppMotion.page,
      curve: AppMotion.pageCurve,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).galleryArtworkAdded)),
    );
  }

  Future<void> _openFirstArtist(BuildContext context) async {
    final result = await pushChildEditor(
      context,
      const ChildEditorArgs(origin: ChildEditorOrigin.galleryEmpty),
    );
    if (!context.mounted || result is! ActionSuccess<String>) return;
    final created =
        (ref.read(allChildrenStreamProvider).value ?? const <Child>[])
            .where((child) => child.id == result.value)
            .firstOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).childEditorCreated(created?.name ?? ''),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    List<Child> children,
    GalleryFilter filter,
  ) async {
    final compositionActions = ref.read(compositionActionsProvider);
    final openShare = compositionActions.openGalleryShare;
    if (openShare == null) return;

    if (filter case OneChild(childId: final childId)) {
      final child = children.where((item) => item.id == childId).firstOrNull;
      if (child != null) {
        openShare(context, child.id, child.name);
      }
      return;
    }
    final child = await showModalBottomSheet<Child>(
      context: context,
      builder: (sheetContext) => _ArtistPickerSheet(children: children),
    );
    if (child != null && context.mounted) {
      openShare(context, child.id, child.name);
    }
  }

  void _retryVault() {
    ref.invalidate(allChildrenStreamProvider);
    ref.invalidate(galleryTilesProvider);
  }

  Future<void> _exportVaultRescue(BuildContext context) async {
    try {
      await ref.read(vaultRescueExportProvider).shareRescueArchive();
    } on RescueExportInsufficientSpaceException catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.vaultRescueInsufficientSpace(
              formatRescueBytes(error.requiredBytes, l10n.localeName),
            ),
          ),
        ),
      );
    }
  }

  int _columns(double width) {
    if (width >= 1280) return 5;
    if (width >= 840) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double _gutter(double width) => width >= 600 ? 12 : 8;
  double _margin(double width) => width >= 840
      ? 32
      : width >= 600
      ? 24
      : 12;

  /// The app bar's actions, left to right: share, sync, people, settings.
  ///
  /// Two rules, and only two, decide whether a control is rendered — mixing
  /// them was how a capability-backed action ended up on a bare null check:
  ///
  /// * **Capability-gated** (share, sync): shown only when the capability is
  ///   enabled *and* the composition bound the action. Both halves are
  ///   required because `ArtKiddoBootstrap` guarantees they agree, so either
  ///   one missing means the feature genuinely is not part of this build.
  /// * **Local-default** (people, settings): always shown, because each has an
  ///   honest account-free destination inside this package. The matching
  ///   `CompositionActions` entry *substitutes* a richer surface; it does not
  ///   gate the control (ADR 0016).
  ///
  /// The trailing margin is positional: the last visible action carries the
  /// screen margin on its right, every earlier one a single-step gap.
  List<Widget> _appBarActions(
    BuildContext context,
    AppCapabilities capabilities,
    CompositionActions actions, {
    required double width,
    required bool shareEnabled,
    required VoidCallback onShare,
  }) {
    final buttons = <Widget>[
      if (capabilities.webGalleryLinks && actions.openGalleryShare != null)
        _ShareButton(enabled: shareEnabled, onPressed: onShare),
      if (capabilities.remoteBackup && actions.syncPhotos != null)
        _SyncButton(onPressed: () => actions.syncPhotos!(context)),
      _FamilyButton(
        opensHousehold: actions.openFamilyHub != null,
        onPressed: () => actions.openFamilyHub != null
            ? actions.openFamilyHub!(context)
            : _pushLocal(context, const ChildrenScreen()),
      ),
      _SettingsButton(
        onPressed: () => actions.openSettings != null
            ? actions.openSettings!(context)
            : _pushLocal(context, const SettingsScreen()),
      ),
    ];
    return [
      for (var i = 0; i < buttons.length; i++)
        Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s1,
            right: i == buttons.length - 1 ? _margin(width) : 0,
          ),
          child: buttons[i],
        ),
    ];
  }

  void _pushLocal(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capabilities = ref.watch(appCapabilitiesProvider);
    final compositionActions = ref.watch(compositionActionsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final filter = ref.watch(galleryFilterProvider);
    final childrenAsync = ref.watch(allChildrenStreamProvider);
    final children = childrenAsync.value ?? const <Child>[];
    final tilesAsync = ref.watch(galleryTilesProvider);
    // An unreadable vault is not an empty first-launch state.
    final vaultUnreadable = childrenAsync.hasError;
    final hasArtists = children.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              toolbarHeight: 64,
              backgroundColor: AppColors.paper,
              surfaceTintColor: Colors.transparent,
              titleSpacing: _margin(width),
              title: Text('ArtKiddo', style: AppTypography.display),
              actions: _appBarActions(
                context,
                capabilities,
                compositionActions,
                width: width,
                // Sharing a gallery link needs at least one artist and a
                // readable vault. The control stays visible and disabled so
                // the absence is legible as "nothing to share yet" rather
                // than as a missing feature.
                shareEnabled: hasArtists && !vaultUnreadable,
                onShare: () => _share(context, children, filter),
              ),
            ),
            if (children.length > 1)
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  child: _FilterBar(
                    children: children,
                    filter: filter,
                    margin: _margin(width),
                    onSelect: (next) {
                      ref.read(galleryFilterProvider.notifier).setFilter(next);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _restoreScroll(),
                      );
                    },
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s2)),
            ..._buildGallerySlivers(
              context,
              l10n,
              tilesAsync,
              filter,
              children,
              vaultUnreadable: vaultUnreadable,
              columns: _columns(width),
              gutter: _gutter(width),
              margin: _margin(width),
            ),
          ],
        ),
      ),
      floatingActionButton: hasArtists && !vaultUnreadable
          ? FloatingActionButton(
              heroTag: 'gallery-capture',
              onPressed: () => _openCapture(
                context,
                childId: switch (filter) {
                  OneChild(childId: final childId) => childId,
                  _ => null,
                },
              ),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.add_a_photo_outlined),
            )
          : null,
    );
  }

  List<Widget> _buildGallerySlivers(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<GalleryTilesState> tilesAsync,
    GalleryFilter filter,
    List<Child> children, {
    required bool vaultUnreadable,
    required int columns,
    required double gutter,
    required double margin,
  }) {
    if (vaultUnreadable) {
      // Keep this branch before the empty state: showing the first-launch copy
      // makes a parent believe the local originals were erased and can cause
      // an irreversible uninstall.
      return [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(margin),
              child: StateBlock(
                intent: StateBlockIntent.error,
                title: l10n.galleryErrorTitle,
                body: l10n.galleryVaultErrorBody,
                actionLabel: l10n.commonRetry,
                onAction: _retryVault,
                secondaryLabel: l10n.vaultRescueExportAction,
                onSecondary: () => _exportVaultRescue(context),
              ),
            ),
          ),
        ),
      ];
    }

    if (children.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.palette_outlined,
            title: l10n.galleryEmptyNoChildTitle,
            body: l10n.galleryEmptyNoChildBody,
            actionLabel: l10n.galleryEmptyNoChildAction,
            onAction: () => _openFirstArtist(context),
          ),
        ),
      ];
    }

    return tilesAsync.when(
      loading: () => [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin, AppSpacing.s3, margin, 104),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadii.artwork),
                ),
              ),
              childCount: columns * 4,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gutter,
              crossAxisSpacing: gutter,
              childAspectRatio: 0.82,
            ),
          ),
        ),
      ],
      error: (_, _) => [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(margin),
              child: StateBlock(
                intent: StateBlockIntent.error,
                title: l10n.galleryErrorTitle,
                body: l10n.galleryVaultErrorBody,
                actionLabel: l10n.commonRetry,
                onAction: _retryVault,
              ),
            ),
          ),
        ),
      ],
      data: (data) {
        if (data.tiles.isEmpty) {
          final selectedChild = filter is OneChild
              ? children
                    .where((child) => child.id == filter.childId)
                    .firstOrNull
              : null;
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.auto_awesome_outlined,
                title: selectedChild == null
                    ? l10n.galleryEmptyNoArtworkTitle
                    : l10n.galleryEmptyFilteredTitle(selectedChild.name),
                body: selectedChild == null
                    ? l10n.galleryEmptyNoArtworkBody
                    : l10n.galleryEmptyFilteredBody,
                actionLabel: selectedChild == null
                    ? l10n.galleryAddArtwork
                    : l10n.galleryAddArtworkFor(selectedChild.name),
                onAction: () =>
                    _openCapture(context, childId: selectedChild?.id),
              ),
            ),
          ];
        }
        final groups = _monthGroups(
          data.tiles,
          Localizations.localeOf(context),
        );
        final slivers = <Widget>[];
        for (var index = 0; index < groups.length; index++) {
          final group = groups[index];
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  index == 0 ? AppSpacing.s3 : AppSpacing.s8,
                  margin,
                  AppSpacing.s3,
                ),
                child: Text(group.label, style: AppTypography.h2),
              ),
            ),
          );
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                margin,
                0,
                margin,
                index == groups.length - 1 ? 104 : 0,
              ),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: gutter,
                crossAxisSpacing: gutter,
                childCount: group.tiles.length,
                itemBuilder: (context, itemIndex) =>
                    MosaicArtworkTile(tile: group.tiles[itemIndex]),
              ),
            ),
          );
        }
        return slivers;
      },
    );
  }

  List<_MonthGroup> _monthGroups(List<ArtworkTile> tiles, Locale locale) {
    final sorted = [...tiles]
      ..sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));
    final groups = <_MonthGroup>[];
    for (final tile in sorted) {
      final date = _dateFor(tile);
      final key = '${date.year}-${date.month}';
      if (groups.isEmpty || groups.last.key != key) {
        groups.add(
          _MonthGroup(
            key: key,
            label: _capitalize(
              DateFormat.yMMMM(locale.toLanguageTag()).format(date),
            ),
            tiles: [tile],
          ),
        );
      } else {
        groups.last.tiles.add(tile);
      }
    }
    return groups;
  }

  DateTime _dateFor(ArtworkTile tile) => tile.drawnAt ?? tile.addedAt;

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _MonthGroup {
  final String key;
  final String label;
  final List<ArtworkTile> tiles;
  _MonthGroup({required this.key, required this.label, required this.tiles});
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _FilterHeaderDelegate({required this.child});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _FilterBar extends StatelessWidget {
  final List<Child> children;
  final GalleryFilter filter;
  final double margin;
  final ValueChanged<GalleryFilter> onSelect;
  const _FilterBar({
    required this.children,
    required this.filter,
    required this.margin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = [...children]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ColoredBox(
      color: AppColors.paper,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        children: [
          AppFilterChip(
            label: l10n.galleryFilterAll,
            selected: filter is AllChildren,
            onTap: () => onSelect(const AllChildren()),
          ),
          for (final child in sorted)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s2),
              child: AppFilterChip(
                label: child.name,
                selected: switch (filter) {
                  OneChild(childId: final selectedId) => selectedId == child.id,
                  _ => false,
                },
                onTap: () => onSelect(OneChild(child.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class MosaicArtworkTile extends ConsumerStatefulWidget {
  final ArtworkTile tile;
  const MosaicArtworkTile({super.key, required this.tile});

  @override
  ConsumerState<MosaicArtworkTile> createState() => _MosaicArtworkTileState();
}

class _MosaicArtworkTileState extends ConsumerState<MosaicArtworkTile> {
  OverlayEntry? _overlayEntry;
  final _peekKey = GlobalKey<_ArtworkPeekOverlayState>();
  bool _isPeeking = false;

  void _startPeek() async {
    if (_isPeeking) return;
    _isPeeking = true;
    HapticFeedback.mediumImpact();

    // Resolve display image file for a sharp zoom preview if already downloaded
    File previewFile = widget.tile.imageFile;
    final bestPath = widget.tile.artwork.bestDisplayImagePath;
    if (bestPath != null) {
      try {
        final vault = ref.read(localVaultProvider);
        final file = await vault.resolveFile(bestPath);
        if (file.existsSync()) {
          previewFile = file;
        }
      } catch (_) {}
    }

    if (!_isPeeking || !mounted) return;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => _ArtworkPeekOverlay(
        key: _peekKey,
        tile: widget.tile,
        previewFile: previewFile,
        onDismiss: _endPeek,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);

    if (widget.tile.hasAudio) {
      _startPeekAudio();
    }
  }

  Future<void> _startPeekAudio() async {
    try {
      final vault = ref.read(localVaultProvider);
      File? audioFile;
      final relPath = widget.tile.artwork.relativeAudioPath;
      if (relPath != null) {
        final f = await vault.resolveFile(relPath);
        if (f.existsSync()) {
          audioFile = f;
        }
      }

      if (audioFile == null &&
          !widget.tile.artwork.isAudioLocal &&
          widget.tile.artwork.hasAudio) {
        final fetcher = ref.read(remoteMediaFetcherProvider);
        await fetcher.ensureAudioDownloaded(widget.tile.artworkId);
        final repo = ref.read(artworksRepositoryProvider);
        final updated = await repo.getById(widget.tile.artworkId);
        if (updated?.relativeAudioPath != null) {
          final f = await vault.resolveFile(updated!.relativeAudioPath!);
          if (f.existsSync()) {
            audioFile = f;
          }
        }
      }

      if (_isPeeking && audioFile != null && audioFile.existsSync()) {
        final player = ref.read(audioPlayerServiceProvider);
        await player.setFilePath(audioFile.path);
        if (_isPeeking) {
          await player.play();
        }
      }
    } catch (e, st) {
      Log.e('Error loading peek audio', e, st, 'GalleryScreen');
    }
  }

  void _endPeek() {
    if (!_isPeeking) return;
    _isPeeking = false;

    try {
      final player = ref.read(audioPlayerServiceProvider);
      player.stop();
    } catch (_) {}

    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    if (_isPeeking) {
      _isPeeking = false;
      try {
        ref.read(audioPlayerServiceProvider).stop();
      } catch (_) {}
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.tile.aspectRatio.clamp(0.60, 1.70);
    final extreme =
        widget.tile.aspectRatio < 0.60 || widget.tile.aspectRatio > 1.70;
    final l10n = AppLocalizations.of(context);
    final date = widget.tile.drawnAt ?? widget.tile.addedAt;
    final label = widget.tile.story == null || widget.tile.story!.isEmpty
        ? l10n.a11yGalleryCard(widget.tile.childName, date, widget.tile.age)
        : l10n.a11yGalleryCardWithStory(
            widget.tile.childName,
            date,
            widget.tile.age,
            widget.tile.story!,
          );
    return Semantics(
      button: true,
      label: label,
      child: Hero(
        tag: 'artwork-${widget.tile.artworkId}',
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) => _startPeek(),
            onLongPressEnd: (_) => _endPeek(),
            onLongPressCancel: () => _endPeek(),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.artwork),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArtworkScreen(
                    artworkId: widget.tile.artworkId,
                    initialArtwork: widget.tile.artwork,
                    initialHeroFile: widget.tile.imageFile,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.artwork),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _TileImage(
                        file: widget.tile.imageFile,
                        exists: widget.tile.imageExists,
                        contain: extreme,
                      ),
                      if (widget.tile.hasAudio)
                        Positioned(
                          right: AppSpacing.s2,
                          bottom: AppSpacing.s2,
                          child: const ExcludeSemantics(
                            child: _TileAudioBadge(),
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
    );
  }
}

class _ArtworkPeekOverlay extends StatefulWidget {
  final ArtworkTile tile;
  final File previewFile;
  final VoidCallback onDismiss;

  const _ArtworkPeekOverlay({
    super.key,
    required this.tile,
    required this.previewFile,
    required this.onDismiss,
  });

  @override
  State<_ArtworkPeekOverlay> createState() => _ArtworkPeekOverlayState();
}

class _ArtworkPeekOverlayState extends State<_ArtworkPeekOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.curve));
    _controller.forward();
  }

  void dismiss(VoidCallback onDone) {
    if (!mounted) {
      onDone();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = math.min(size.width * 0.88, 480.0);
    final maxHeight = size.height * 0.72;

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 32,
                                spreadRadius: 2,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AspectRatio(
                            aspectRatio: widget.tile.aspectRatio.clamp(
                              0.55,
                              1.8,
                            ),
                            child: widget.tile.imageExists
                                ? Image.file(
                                    widget.previewFile,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  )
                                : const ColoredBox(
                                    color: AppColors.surfaceSunken,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.inkMuted,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (widget.tile.hasAudio) ...[
                        const SizedBox(height: AppSpacing.s3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                            vertical: AppSpacing.s2 + 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _AudioPulsingWaves(),
                              const SizedBox(width: AppSpacing.s2 + 2),
                              Text(
                                widget.tile.childName.isNotEmpty
                                    ? 'Voix de ${widget.tile.childName}'
                                    : 'Écoute de l’anecdote...',
                                style: AppTypography.bodyStrong.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.tile.story != null &&
                          widget.tile.story!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s2),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                          ),
                          child: Text(
                            '« ${widget.tile.story} »',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontStyle: FontStyle.italic,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPulsingWaves extends StatefulWidget {
  const _AudioPulsingWaves();

  @override
  State<_AudioPulsingWaves> createState() => _AudioPulsingWavesState();
}

class _AudioPulsingWavesState extends State<_AudioPulsingWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(6 + 8 * v),
            const SizedBox(width: 3),
            _bar(14 - 8 * v),
            const SizedBox(width: 3),
            _bar(8 + 8 * (1 - v)),
            const SizedBox(width: 3),
            _bar(5 + 10 * v),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TileAudioBadge extends StatelessWidget {
  const _TileAudioBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.overlay,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surface.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.mic_rounded, size: 14, color: AppColors.surface),
      ),
    );
  }
}

class _TileImage extends StatelessWidget {
  final File file;
  final bool exists;
  final bool contain;
  const _TileImage({
    required this.file,
    required this.exists,
    required this.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (!exists) {
      return const ColoredBox(
        color: AppColors.surfaceSunken,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.inkMuted,
          ),
        ),
      );
    }
    return ColoredBox(
      color: AppColors.surface,
      child: Image.file(
        file,
        fit: contain ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _ShareButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.ios_share_outlined, size: 18),
      label: Text(l10n.shareGalleryHeading),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.onAccent,
        backgroundColor: AppColors.share,
        disabledForegroundColor: AppColors.inkDisabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        textStyle: AppTypography.label,
      ),
    );
  }
}

/// Manual photo sync is a one-tap chore on the artwork wall, not a family
/// setting — which is why it is labelled from a gallery-owned key rather
/// than a `familyHub*` one. Rendered only when `remoteBackup` is enabled
/// *and* the composition bound `syncPhotos`; that composition runs the sync
/// and reports progress and outcome itself, since this package models no
/// sync status.
class _SyncButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SyncButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.gallerySyncPhotos,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.cloud_sync_outlined),
    );
  }
}

/// People surface. Its local default is the children list, so the tooltip
/// names whichever destination this build actually opens: a composition
/// substituting a household hub says "Famille", the account-free build says
/// "Enfants". Labelling the local build "Famille" would promise a household
/// that no account-free composition has.
class _FamilyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool opensHousehold;
  const _FamilyButton({required this.onPressed, required this.opensHousehold});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: opensHousehold ? l10n.familyTitle : l10n.childrenTitle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.people_outline),
    );
  }
}

/// Global settings live one tap from the gallery, not buried inside the
/// family hub. The debug-only screen is reached from inside settings.
class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.settingsTitle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
    );
  }
}

class _ArtistPickerSheet extends StatelessWidget {
  final List<Child> children;
  const _ArtistPickerSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
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
            Text(l10n.artworkShareGallery, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s1),
            Text(
              l10n.shareGalleryPickerBody,
              style: AppTypography.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s3),
            for (final child in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: AppSpacing.s2,
                leading: CircleAvatar(
                  backgroundColor: AppColors.shareSurface,
                  foregroundColor: AppColors.share,
                  child: Text(
                    child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
                  ),
                ),
                title: Text(child.name, style: AppTypography.bodyStrong),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(child),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSourceSheet extends StatelessWidget {
  const _CaptureSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
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
            Text(l10n.galleryAddArtwork, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s2),
            _CaptureSourceRow(
              icon: Icons.camera_alt_outlined,
              title: l10n.captureSourceCameraTitle,
              subtitle: l10n.captureSourceCameraBody,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _CaptureSourceRow(
              icon: Icons.photo_library_outlined,
              title: l10n.captureSourceGalleryTitle,
              subtitle: l10n.captureSourceGalleryBody,
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSourceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CaptureSourceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: AppSpacing.s3,
    leading: Icon(icon, size: 28, color: AppColors.accent),
    title: Text(title, style: AppTypography.bodyStrong),
    subtitle: Text(
      subtitle,
      style: AppTypography.body.copyWith(color: AppColors.inkMuted),
    ),
    onTap: onTap,
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'masonry_layout.dart';
import '../navigation/composition_actions.dart';
import 'gallery_providers.dart';

/// ArtKiddo's product surface: a calm, chronological wall of artwork.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  static const _appBarHeight = 64.0;

  final ScrollController _scrollController = ScrollController();

  /// The feed exactly as laid out, newest first, and the delegate that
  /// placed it: together they map a scroll offset back to a tile's month.
  List<ArtworkTile> _feed = const [];
  SliverGridDelegateWithMasonryPlan? _gridDelegate;

  /// The month label is transient: it names where the parent is while the
  /// feed moves and fades out once it rests, so the feed itself stays one
  /// continuous wall with no headers.
  final ValueNotifier<String?> _scrollMonth = ValueNotifier(null);
  final ValueNotifier<bool> _scrollMonthVisible = ValueNotifier(false);
  Timer? _hideScrollMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    _scrollController.addListener(_saveScroll);
  }

  @override
  void dispose() {
    _hideScrollMonth?.cancel();
    _scrollMonth.dispose();
    _scrollMonthVisible.dispose();
    _scrollController
      ..removeListener(_saveScroll)
      ..dispose();
    super.dispose();
  }

  bool _onFeedScroll(ScrollNotification notification) {
    // Only the feed itself: the horizontal filter bar nests its own
    // scrollable inside this one.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      _hideScrollMonth?.cancel();
      final month = _monthAt(notification.metrics.pixels);
      _scrollMonth.value = month;
      // Near the top the newest artworks speak for themselves.
      _scrollMonthVisible.value =
          month != null &&
          notification.metrics.pixels >
              notification.metrics.viewportDimension / 2;
    } else if (notification is ScrollEndNotification) {
      _hideScrollMonth?.cancel();
      _hideScrollMonth = Timer(const Duration(seconds: 1), () {
        if (mounted) _scrollMonthVisible.value = false;
      });
    }
    return false;
  }

  /// Month of the first tile at the top of the viewport. Pinned headers
  /// keep their scroll extent, so the viewport's top edge in feed
  /// coordinates is simply the scroll offset minus the feed's top padding.
  String? _monthAt(double pixels) {
    final plan = _gridDelegate?.lastPlan;
    if (plan == null || plan.length == 0 || plan.length != _feed.length) {
      return null;
    }
    final index = math.min(
      plan.firstIndexBelow(pixels - AppSpacing.s3),
      plan.length - 1,
    );
    return _capitalize(
      DateFormat.yMMMM(
        Localizations.localeOf(context).toLanguageTag(),
      ).format(_dateFor(_feed[index])),
    );
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

  /// The app bar's actions, left to right: share, people, settings.
  ///
  /// Two rules, and only two, decide whether a control is rendered — mixing
  /// them was how a capability-backed action ended up on a bare null check:
  ///
  /// * **Capability-gated** (share): shown only when the capability is
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
        _ShareButton(
          enabled: shareEnabled,
          onPressed: onShare,
          // 600 is the phone/tablet grid breakpoint, not a title-fit one:
          // every phone falls under it, so reusing it here made the button
          // compact unconditionally. This narrower cutoff only kicks in on
          // genuinely tight widths (small phones, split screen).
          compact: width < 400,
        ),
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
    final showFilter = children.length > 1;
    // Pinned chrome above the feed: the app bar, plus the filter bar when
    // there is more than one artist to filter by.
    final chromeExtent =
        _appBarHeight + (showFilter ? _FilterHeaderDelegate.height : 0);
    // Capability-gated like share (ADR 0016): the gesture exists only when
    // the build backs up remotely *and* the composition bound the action.
    // A local build has nothing to pull, so it gets no gesture at all
    // rather than a spinner that syncs nothing.
    final syncPhotos = capabilities.remoteBackup && !vaultUnreadable
        ? compositionActions.syncPhotos
        : null;

    Widget feed = NotificationListener<ScrollNotification>(
      onNotification: _onFeedScroll,
      child: CustomScrollView(
        controller: _scrollController,
        // The pull gesture must work on a short or empty feed too.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            toolbarHeight: _appBarHeight,
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
          if (showFilter)
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeaderDelegate(
                child: _FilterBar(
                  children: children,
                  filter: filter,
                  margin: _margin(width),
                  onSelect: (next) {
                    _scrollMonthVisible.value = false;
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
    );
    if (syncPhotos != null) {
      feed = RefreshIndicator(
        // Starts below the pinned chrome, where the feed actually begins.
        edgeOffset: chromeExtent,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        // Resolves as soon as the sync is launched: the composition owns
        // progress and outcome (see `CompositionActions.syncPhotos`), so a
        // spinner held for the whole run would be a second, mute indicator.
        onRefresh: () async => syncPhotos(context),
        child: feed,
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            feed,
            Positioned(
              top: chromeExtent + AppSpacing.s2,
              left: 0,
              right: 0,
              child: Center(
                child: _ScrollMonthLabel(
                  month: _scrollMonth,
                  visible: _scrollMonthVisible,
                ),
              ),
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
        // One continuous wall, newest first: no month headers. Where the
        // parent is in time shows only while scrolling (`_ScrollMonthLabel`).
        final feed = [...data.tiles]
          ..sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));
        final ratios = [
          for (final tile in feed) MosaicArtworkTile.ratioOf(tile),
        ];
        final previous = _gridDelegate;
        // Reusing an equivalent delegate keeps its computed plan instead of
        // re-placing every tile on each rebuild.
        final delegate =
            previous != null &&
                previous.columns == columns &&
                previous.gutter == gutter &&
                listEquals(previous.aspectRatios, ratios)
            ? previous
            : SliverGridDelegateWithMasonryPlan(
                aspectRatios: ratios,
                columns: columns,
                gutter: gutter,
              );
        _feed = feed;
        _gridDelegate = delegate;
        final indexById = {
          for (var i = 0; i < feed.length; i++) feed[i].artworkId: i,
        };
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, AppSpacing.s3, margin, 104),
            sliver: SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) => MosaicArtworkTile(
                  key: ValueKey(feed[index].artworkId),
                  tile: feed[index],
                ),
                childCount: feed.length,
                // A new capture lands at index 0; keyed lookup keeps each
                // mounted tile (and a peek in progress) on its artwork.
                findChildIndexCallback: (key) =>
                    indexById[(key as ValueKey<String>).value],
              ),
            ),
          ),
        ];
      },
    );
  }

  DateTime _dateFor(ArtworkTile tile) => tile.drawnAt ?? tile.addedAt;

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const height = 52.0;

  final Widget child;
  const _FilterHeaderDelegate({required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
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

/// Transient month pill shown over the feed while it scrolls.
///
/// Decorative for assistive technology: every tile already announces its
/// own date, and a label that appears and fades on motion would only repeat
/// it out of context.
class _ScrollMonthLabel extends StatelessWidget {
  final ValueListenable<String?> month;
  final ValueListenable<bool> visible;
  const _ScrollMonthLabel({required this.month, required this.visible});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, isVisible, child) => AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: AppMotion.standard,
            curve: AppMotion.curve,
            child: child,
          ),
          child: ValueListenableBuilder<String?>(
            valueListenable: month,
            builder: (context, value, _) => value == null
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s2,
                      ),
                      child: Text(
                        value,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink,
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

class MosaicArtworkTile extends ConsumerStatefulWidget {
  final ArtworkTile tile;
  const MosaicArtworkTile({super.key, required this.tile});

  static const _minRatio = 0.60;
  static const _maxRatio = 1.70;

  /// The ratio a tile is displayed at. Extreme drawings are clamped (and
  /// shown uncropped inside that frame) so one panorama or scroll cannot
  /// dominate the wall. The feed's layout plan uses this same value.
  static double ratioOf(ArtworkTile tile) =>
      tile.aspectRatio.clamp(_minRatio, _maxRatio);

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
    final ratio = MosaicArtworkTile.ratioOf(widget.tile);
    final extreme = ratio != widget.tile.aspectRatio;
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
                      _PeekHeader(tile: widget.tile),
                      const SizedBox(height: AppSpacing.s3),
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
                                    ? AppLocalizations.of(
                                        context,
                                      ).galleryPeekVoiceOf(
                                        widget.tile.childName,
                                      )
                                    : AppLocalizations.of(
                                        context,
                                      ).galleryPeekListening,
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

/// When and by whom, above the peeked artwork: the two facts a parent
/// looks for first, readable on the blurred backdrop without opening it.
class _PeekHeader extends StatelessWidget {
  final ArtworkTile tile;
  const _PeekHeader({required this.tile});

  static const _shadows = [Shadow(color: Colors.black54, blurRadius: 8)];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawnAt = tile.drawnAt;
    // Say which date this is (CONTEXT.md invariant 3): the parent-supplied
    // drawing date, or only the day it was added.
    final date = drawnAt != null
        ? l10n.artworkDrawnOn(drawnAt)
        : l10n.artworkAddedOn(tile.addedAt);
    final artist = [
      if (tile.childName.isNotEmpty) tile.childName,
      if (tile.age.isNotEmpty) tile.age,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            textAlign: TextAlign.center,
            style: AppTypography.h3.copyWith(
              color: Colors.white,
              shadows: _shadows,
            ),
          ),
          if (artist.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              artist,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                shadows: _shadows,
              ),
            ),
          ],
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
  final bool compact;
  const _ShareButton({
    required this.enabled,
    required this.onPressed,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (compact) {
      // Icon-only on narrow screens: the "Share" label would otherwise
      // steal the width the "ArtKiddo" title needs and get it cropped.
      return IconButton(
        tooltip: l10n.shareGalleryHeading,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          foregroundColor: AppColors.onAccent,
          backgroundColor: AppColors.share,
          disabledForegroundColor: AppColors.inkDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        ),
        icon: const Icon(Icons.ios_share_outlined, size: 18),
      );
    }
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

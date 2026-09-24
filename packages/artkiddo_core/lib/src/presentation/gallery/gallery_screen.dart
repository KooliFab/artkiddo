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

part 'gallery_screen_tiles.dart';
part 'gallery_screen_peek.dart';
part 'gallery_screen_chrome.dart';

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

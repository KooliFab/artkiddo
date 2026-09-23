import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Exact masonry placement for tiles whose aspect ratios are known up front.
///
/// Every gallery tile carries its ratio before it is built, so the feed can
/// be laid out completely instead of estimated. A lazily measured masonry
/// only knows the heights it has built so far: it has to estimate its total
/// extent and correct the scroll offset as it discovers tiles, which moved
/// the viewport under the parent's finger and made the end of a long feed
/// unreachable.
///
/// Each tile goes to the currently shortest column. That column's height
/// never decreases, so tile tops are non-decreasing in index order, and the
/// scroll-offset lookups below can be binary searches.
@immutable
class MasonryPlan {
  final int columns;
  final double gutter;
  final double crossAxisExtent;
  final double tileWidth;
  final List<double> _tops;
  final List<double> _heights;
  final List<int> _columns;

  /// Running maximum of tile bottoms. Unlike the bottoms themselves it is
  /// monotonic, which is what makes [firstIndexBelow] searchable.
  final List<double> _maxBottoms;

  /// Height of the tallest column: the exact scroll extent of the feed.
  final double extent;

  factory MasonryPlan({
    required List<double> aspectRatios,
    required int columns,
    required double gutter,
    required double crossAxisExtent,
  }) {
    assert(columns > 0);
    final tileWidth = math.max(
      0.0,
      (crossAxisExtent - gutter * (columns - 1)) / columns,
    );
    final heights = List<double>.filled(columns, 0);
    final tops = <double>[];
    final tileHeights = <double>[];
    final tileColumns = <int>[];
    final maxBottoms = <double>[];
    var maxBottom = 0.0;
    for (final ratio in aspectRatios) {
      var column = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[column]) column = i;
      }
      final top = heights[column];
      final height = ratio > 0 ? tileWidth / ratio : tileWidth;
      tops.add(top);
      tileHeights.add(height);
      tileColumns.add(column);
      heights[column] = top + height + gutter;
      maxBottom = math.max(maxBottom, top + height);
      maxBottoms.add(maxBottom);
    }
    return MasonryPlan._(
      columns: columns,
      gutter: gutter,
      crossAxisExtent: crossAxisExtent,
      tileWidth: tileWidth,
      tops: tops,
      heights: tileHeights,
      tileColumns: tileColumns,
      maxBottoms: maxBottoms,
      extent: maxBottom,
    );
  }

  const MasonryPlan._({
    required this.columns,
    required this.gutter,
    required this.crossAxisExtent,
    required this.tileWidth,
    required this._tops,
    required this._heights,
    required List<int> tileColumns,
    required this._maxBottoms,
    required this.extent,
  }) : _columns = tileColumns;

  int get length => _tops.length;

  double topOf(int index) => _tops[index];
  double heightOf(int index) => _heights[index];
  int columnOf(int index) => _columns[index];
  double crossAxisOffsetOf(int index) => _columns[index] * (tileWidth + gutter);

  /// Smallest index whose tile extends below [offset]: every earlier tile
  /// lies entirely above it. Returns [length] when none does.
  int firstIndexBelow(double offset) {
    var low = 0;
    var high = length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_maxBottoms[mid] > offset) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  /// Largest index whose tile starts above [offset]; `-1` when none does.
  int lastIndexAbove(double offset) {
    var low = 0;
    var high = length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_tops[mid] < offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }
}

/// A [SliverGridDelegate] that places children with a [MasonryPlan], so
/// [SliverGrid] reports an exact scroll extent instead of estimating one.
class SliverGridDelegateWithMasonryPlan extends SliverGridDelegate {
  final List<double> aspectRatios;
  final int columns;
  final double gutter;

  SliverGridDelegateWithMasonryPlan({
    required this.aspectRatios,
    required this.columns,
    required this.gutter,
  });

  MasonryPlan? _plan;

  /// The plan from the most recent layout, for callers that map a scroll
  /// offset back to a tile (the month label). Null before the first layout.
  MasonryPlan? get lastPlan => _plan;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final cached = _plan;
    final plan =
        cached != null && cached.crossAxisExtent == constraints.crossAxisExtent
        ? cached
        : MasonryPlan(
            aspectRatios: aspectRatios,
            columns: columns,
            gutter: gutter,
            crossAxisExtent: constraints.crossAxisExtent,
          );
    _plan = plan;
    return _MasonryGridLayout(plan);
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithMasonryPlan oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.gutter != gutter ||
      !listEquals(oldDelegate.aspectRatios, aspectRatios);
}

class _MasonryGridLayout extends SliverGridLayout {
  final MasonryPlan plan;
  const _MasonryGridLayout(this.plan);

  int get _last => math.max(0, plan.length - 1);

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      math.min(plan.firstIndexBelow(scrollOffset), _last);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      plan.lastIndexAbove(scrollOffset).clamp(0, _last);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    if (index >= plan.length) {
      // Past the end: a zero-size cell at the bottom, never painted.
      return SliverGridGeometry(
        scrollOffset: plan.extent,
        crossAxisOffset: 0,
        mainAxisExtent: 0,
        crossAxisExtent: plan.tileWidth,
      );
    }
    return SliverGridGeometry(
      scrollOffset: plan.topOf(index),
      crossAxisOffset: plan.crossAxisOffsetOf(index),
      mainAxisExtent: plan.heightOf(index),
      crossAxisExtent: plan.tileWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) => plan.extent;
}

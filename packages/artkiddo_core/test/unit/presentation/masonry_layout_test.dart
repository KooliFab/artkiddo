import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/presentation/gallery/masonry_layout.dart';

void main() {
  MasonryPlan plan(List<double> ratios, {int columns = 2}) => MasonryPlan(
    aspectRatios: ratios,
    columns: columns,
    gutter: 10,
    crossAxisExtent: 210,
  );

  test('each tile goes to the currently shortest column', () {
    // Tile width is (210 - 10) / 2 = 100.
    final p = plan([0.5, 1, 1, 2]);
    expect(p.tileWidth, 100);
    // 0: col 0, 0..200. 1: col 1, 0..100. 2: col 1 (110 < 210), 110..210.
    // 3: col 0 (210, gutter included) is shorter than col 1 (220).
    expect([for (var i = 0; i < 4; i++) p.columnOf(i)], [0, 1, 1, 0]);
    expect([for (var i = 0; i < 4; i++) p.topOf(i)], [0, 0, 110, 210]);
    expect(p.heightOf(3), 50);
    expect(p.crossAxisOffsetOf(1), 110);
  });

  test('the extent is the tallest column, without a trailing gutter', () {
    final p = plan([0.5, 1, 1, 2]);
    expect(p.extent, 260);
    expect(plan(const []).extent, 0);
  });

  test('tops never decrease, whatever the ratios', () {
    final random = math.Random(7);
    final p = plan([
      for (var i = 0; i < 500; i++) 0.6 + random.nextDouble() * 1.1,
    ], columns: 3);
    for (var i = 1; i < p.length; i++) {
      expect(p.topOf(i), greaterThanOrEqualTo(p.topOf(i - 1)));
    }
  });

  test('offset lookups bracket exactly the tiles that cross a window', () {
    final random = math.Random(11);
    final p = plan([
      for (var i = 0; i < 300; i++) 0.6 + random.nextDouble() * 1.1,
    ], columns: 3);
    for (var probe = 0; probe < 200; probe++) {
      final start = random.nextDouble() * p.extent;
      final end = start + 700;
      final first = p.firstIndexBelow(start);
      final last = p.lastIndexAbove(end);
      for (var i = 0; i < p.length; i++) {
        final visible = p.topOf(i) < end && p.topOf(i) + p.heightOf(i) > start;
        if (visible) {
          expect(i, inInclusiveRange(first, last), reason: 'tile $i');
        }
      }
      // Nothing before `first` reaches into the window.
      for (var i = 0; i < first; i++) {
        expect(p.topOf(i) + p.heightOf(i), lessThanOrEqualTo(start));
      }
    }
  });

  test('delegate relayouts only when the placement inputs change', () {
    SliverGridDelegateWithMasonryPlan d(List<double> r, {int columns = 2}) =>
        SliverGridDelegateWithMasonryPlan(
          aspectRatios: r,
          columns: columns,
          gutter: 8,
        );
    expect(d([1, 2]).shouldRelayout(d([1, 2])), isFalse);
    expect(d([1, 2]).shouldRelayout(d([2, 1])), isTrue);
    expect(d([1, 2]).shouldRelayout(d([1, 2], columns: 3)), isTrue);
  });
}

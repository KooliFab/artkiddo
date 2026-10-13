// Keeps `app_tokens.dart` in lockstep with `design/tokens.json`, the single
// source the web site also generates its CSS from. A token changed in one
// place and not the other fails here instead of drifting silently.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  final tokens =
      jsonDecode(File('design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;
  final colors = (tokens['color'] as Map).cast<String, String>();

  int resolve(String value) {
    var v = value;
    for (var depth = 0; v.startsWith('{'); depth++) {
      expect(depth, lessThan(8), reason: 'alias cycle at $value');
      v = colors[v.substring(1, v.length - 1)]!;
    }
    final hex = v.substring(1);
    // #RRGGBB or #RRGGBBAA → 0xAARRGGBB
    final rgb = hex.substring(0, 6);
    final alpha = hex.length == 8 ? hex.substring(6) : 'FF';
    return int.parse('$alpha$rgb', radix: 16);
  }

  test('colours match design/tokens.json', () {
    final dart = <String, Color>{
      'paper': AppColors.paper,
      'surface': AppColors.surface,
      'surface-sunken': AppColors.surfaceSunken,
      'ink': AppColors.ink,
      'ink-muted': AppColors.inkMuted,
      'ink-disabled': AppColors.inkDisabled,
      'accent': AppColors.accent,
      'accent-pressed': AppColors.accentPressed,
      'accent-surface': AppColors.accentSurface,
      'on-accent': AppColors.onAccent,
      'share': AppColors.share,
      'share-pressed': AppColors.sharePressed,
      'share-surface': AppColors.shareSurface,
      'sage-surface': AppColors.sageSurface,
      'sage-ink': AppColors.sageInk,
      'lavender-surface': AppColors.lavenderSurface,
      'lavender-ink': AppColors.lavenderInk,
      'ochre': AppColors.ochre,
      'ochre-surface': AppColors.ochreSurface,
      'ochre-ink': AppColors.ochreInk,
      'border': AppColors.border,
      'border-strong': AppColors.borderStrong,
      'danger': AppColors.danger,
      'danger-surface': AppColors.dangerSurface,
      'success': AppColors.success,
      'success-surface': AppColors.successSurface,
      'warning': AppColors.warning,
      'warning-surface': AppColors.warningSurface,
      'overlay': AppColors.overlay,
      'immersive': AppColors.immersive,
      'focus-ring': AppColors.focusRing,
      'disabled-bg': AppColors.disabledBg,
      'scrim-soft': AppColors.scrimSoft,
      'scrim': AppColors.scrim,
      'scrim-strong': AppColors.scrimStrong,
    };
    expect(dart.keys.toSet(), colors.keys.toSet());
    for (final entry in dart.entries) {
      expect(
        entry.value.toARGB32(),
        resolve(colors[entry.key]!),
        reason: 'colour ${entry.key}',
      );
    }
  });

  test('child colours match design/tokens.json', () {
    final child = (tokens['child'] as List).cast<Map<String, dynamic>>();
    expect(AppChildColors.surfaces.length, child.length);
    for (var i = 0; i < child.length; i++) {
      expect(
        AppChildColors.surface(i).toARGB32(),
        resolve(child[i]['surface'] as String),
      );
      expect(
        AppChildColors.ink(i).toARGB32(),
        resolve(child[i]['ink'] as String),
      );
    }
  });

  test('spacing, radii and sizes match design/tokens.json', () {
    final space = (tokens['space'] as Map).cast<String, num>();
    expect(space, {
      's1': AppSpacing.s1,
      's2': AppSpacing.s2,
      's3': AppSpacing.s3,
      's4': AppSpacing.s4,
      's5': AppSpacing.s5,
      's6': AppSpacing.s6,
      's8': AppSpacing.s8,
      's10': AppSpacing.s10,
      's12': AppSpacing.s12,
      's16': AppSpacing.s16,
    });
    final radius = (tokens['radius'] as Map).cast<String, num>();
    expect(radius, {
      'xs': AppRadii.xs,
      'artwork': AppRadii.artwork,
      'sm': AppRadii.sm,
      'md': AppRadii.md,
      'lg': AppRadii.lg,
      'full': AppRadii.full,
    });
    final size = (tokens['size'] as Map).cast<String, num>();
    expect(size, {
      'button': AppSizes.button,
      'button-text': AppSizes.buttonText,
      'chip': AppSizes.chip,
      'avatar': AppSizes.avatar,
      'avatar-small': AppSizes.avatarSmall,
      'badge': AppSizes.badge,
      'banner': AppSizes.banner,
      'shutter': AppSizes.shutter,
      'fab-clearance': AppSizes.fabClearance,
      'tap-target': kMinTapTarget,
    });
  });

  test('shadows and durations match design/tokens.json', () {
    final shadow = (tokens['shadow'] as Map)
        .cast<String, Map<String, dynamic>>();
    void check(String name, List<BoxShadow> list) {
      final spec = shadow[name]!;
      expect(list, hasLength(1), reason: 'shadow $name');
      expect(list.single.offset.dy, spec['y'], reason: 'shadow $name y');
      expect(list.single.blurRadius, spec['blur'], reason: 'shadow $name blur');
      expect(
        list.single.color.toARGB32(),
        resolve(spec['color'] as String),
        reason: 'shadow $name colour',
      );
    }

    check('sm', AppShadows.sm);
    check('lg', AppShadows.lg);
    final duration = (tokens['duration'] as Map).cast<String, num>();
    expect(duration, {
      'micro': AppMotion.micro.inMilliseconds,
      'standard': AppMotion.standard.inMilliseconds,
      'page': AppMotion.page.inMilliseconds,
      'pulse': AppMotion.pulse.inMilliseconds,
      'linger': AppMotion.linger.inMilliseconds,
      'highlight': AppMotion.highlight.inMilliseconds,
      'snack-bar': AppMotion.snackBar.inMilliseconds,
      'snack-bar-long': AppMotion.snackBarLong.inMilliseconds,
    });
  });

  test('type scale matches design/tokens.json', () {
    final type = (tokens['type'] as Map).cast<String, Map<String, dynamic>>();
    final dart = <String, TextStyle>{
      'display': AppTypography.display,
      'h1': AppTypography.h1,
      'h2': AppTypography.h2,
      'h3': AppTypography.h3,
      'body-large': AppTypography.bodyLarge,
      'body': AppTypography.body,
      'body-strong': AppTypography.bodyStrong,
      'label': AppTypography.label,
      'caption': AppTypography.caption,
      'button': AppTypography.button,
      'mono': AppTypography.mono,
      'code': AppTypography.code,
    };
    expect(dart.keys.toSet(), type.keys.toSet());
    for (final entry in dart.entries) {
      final spec = type[entry.key]!;
      final style = entry.value;
      final size = (spec['size'] as num).toDouble();
      expect(style.fontSize, size, reason: '${entry.key} size');
      expect(
        style.height! * size,
        closeTo((spec['line'] as num).toDouble(), 0.001),
        reason: '${entry.key} line height',
      );
      expect(
        style.fontWeight!.value,
        spec['weight'],
        reason: '${entry.key} weight',
      );
      expect(
        style.letterSpacing ?? 0,
        closeTo((spec['tracking'] as num).toDouble(), 0.001),
        reason: '${entry.key} tracking',
      );
      final mono = spec['family'] == 'mono';
      expect(
        style.fontFamily,
        mono ? AppTypography.monoFamily : AppTypography.family,
        reason: '${entry.key} family',
      );
    }
  });
}

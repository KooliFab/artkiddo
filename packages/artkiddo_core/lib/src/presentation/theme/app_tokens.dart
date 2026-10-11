import 'package:flutter/widgets.dart';

/// Exact design tokens transposed from reference design tokens.
///
/// Values are exact, not intentions. Do not invent new colors, spacing or
/// radii outside this set.
abstract final class AppColors {
  static const paper = Color(0xFFF7F2EA);
  static const surface = Color(0xFFFFFDFC);
  static const surfaceSunken = Color(0xFFF0E8DE);
  static const ink = Color(0xFF27221D);
  static const inkMuted = Color(0xFF625A51);
  static const inkDisabled = Color(0xFF8A8178);
  static const accent = Color(0xFFA84732);
  static const accentPressed = Color(0xFF823727);
  static const accentSurface = Color(0xFFF6ECE9);
  static const onAccent = Color(0xFFFFFFFF);
  static const share = Color(0xFF315F95);
  static const sharePressed = Color(0xFF254A76);
  static const shareSurface = Color(0xFFE9EFF7);
  static const sageSurface = Color(0xFFE6EEE6);
  static const sageInk = Color(0xFF4C6B55);
  static const lavenderSurface = Color(0xFFF0EBF6);
  static const lavenderInk = Color(0xFF59476F);
  static const ochre = Color(0xFFD49A28);
  static const ochreSurface = Color(0xFFF6EBD0);
  static const border = Color(0xFFDED4C8);
  static const borderStrong = Color(0xFFB7AA9A);
  static const danger = Color(0xFFB33B32);
  static const dangerSurface = Color(0xFFF7E7E4);
  static const success = Color(0xFF4C6B55);
  static const successSurface = Color(0xFFE6EEE6);
  static const warning = Color(0xFF8A5A00);
  static const warningSurface = Color(0xFFFBF0DC);
  static const overlay = Color(0x7A27221D);
  static const immersive = Color(0xFF1D1915);
  static const focusRing = Color(0xFFA84732);
  static const disabledBg = Color(0x00FFFFFF);

  /// Foreground on photo, camera and other immersive (dark) surfaces.
  static const onImmersive = Color(0xFFFFFFFF);
  static const onImmersiveMuted = Color(0xB3FFFFFF);
  static const onImmersiveSubtle = Color(0x8AFFFFFF);

  /// The camera viewfinder stays pure black, unlike the warm [immersive].
  static const cameraBackdrop = Color(0xFF000000);

  /// Blurred backdrop behind the gallery peek preview.
  static const peekScrim = Color(0xA6000000);

  /// Elevation shadow for Material surfaces that take a single color.
  static const shadow = Color(0x33000000);

  /// A QR code needs a pure white quiet zone to scan reliably.
  static const qrBackground = Color(0xFFFFFFFF);
}

abstract final class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
}

abstract final class AppRadii {
  /// Progress tracks, sheet handles and other thin bars.
  static const xs = 4.0;
  static const sm = 14.0;
  static const artwork = 10.0;
  static const lg = 28.0;
  static const full = 999.0;
}

abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x1427221D), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const md = [
    BoxShadow(color: Color(0x142D2A26), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1F2D2A26), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Small badge floating over an artwork thumbnail.
  static const badge = [
    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Pill or round button floating over content.
  static const floating = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const floatingRound = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  /// The gallery peek card and its action pill, over [AppColors.peekScrim].
  static const peekCard = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 32,
      spreadRadius: 2,
      offset: Offset(0, 12),
    ),
  ];
  static const peekPill = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Keeps text legible when it sits directly on a photo.
  static const textOnImage = [Shadow(color: Color(0x8A000000), blurRadius: 8)];
  static const textOnImageStrong = [
    Shadow(color: Color(0xDD000000), blurRadius: 8),
  ];
}

/// Text styles. Font family attached by [AppTheme].
abstract final class AppTypography {
  /// Explicit on every token so locally supplied styles cannot fall back to
  /// the platform's default font family instead of the ArtKiddo voice.
  ///
  /// Package-qualified because the font asset is declared by this package:
  /// a bare family name only resolves in an app that re-declares the font.
  static const family = 'packages/artkiddo_core/Playpen Sans';

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
  );
  static const h1 = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const h2 = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 26 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );
  static const h3 = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const bodyLarge = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
  );
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
  );
  static const mono = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    fontFamilyFallback: ['Menlo', 'monospace'],
  );

  /// A short code the user reads aloud or copies, such as a family invite.
  static const code = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    fontFamilyFallback: ['Menlo', 'monospace'],
  );
}

abstract final class AppMotion {
  static const micro = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 280);
  static const highlight = Duration(milliseconds: 1200);
  static const snackBar = Duration(seconds: 4);
  static const curve = Curves.easeOutCubic;
  static const pageCurve = Curves.easeInOutCubic;
}

/// Responsive layout breakpoints.
abstract final class AppBreakpoints {
  static const compactMax = 599.0;
  static const mediumMax = 839.0;
  static const expandedMax = 1279.0;

  static bool isCompact(double width) => width < 600;
  static bool isMedium(double width) => width >= 600 && width < 840;
  static bool isExpanded(double width) => width >= 840;
}

const double kMinTapTarget = 48.0;

// Doji design tokens.
//
// SOURCE OF TRUTH: Claude Design › "Doji hero screens review" ›
// Doji Design System.dc.html (snapshot in design/system/, see design/SOURCE.md).
// To change a token: change it in Claude Design, re-sync design/system/, then
// mirror it here. Never hand-edit a value only in Flutter.
import 'package:flutter/material.dart';

/// DojiColors — design system section 02 "Colour".
abstract final class DojiColors {
  static const Color bg = Color(0xFF050607);
  static const Color elevated1 = Color(0xFF0F1113);
  static const Color elevated2 = Color(0xFF17191C);
  static const Color separator = Color(0xFF26292E);

  /// Inner row divider used by lists in the handoff (parsed rows, settings).
  static const Color divider = Color(0xFF1C1E22);

  /// Light-mode background. Only used by the stubbed light theme for now.
  static const Color bone = Color(0xFFF3F1EA);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1A6);

  /// ≈4.0:1 on bg — the design system allows it for 20pt+ text only.
  static const Color textTertiary = Color(0xFF6E6E73);

  /// Primary action, rule kept. Never shown without a text label.
  static const Color dojiGreen = Color(0xFF2FD67B);

  /// Risk, rule broken. Never shown without a text label.
  static const Color tiltOrange = Color(0xFFFF9F0A);

  /// DojiColors.grid[0–4]: no points → full discipline.
  static const List<Color> grid = [
    Color(0xFF101A14),
    Color(0xFF16391F),
    Color(0xFF1E6B3E),
    Color(0xFF27A35C),
    Color(0xFF2FD67B),
  ];

  /// rgba(47,214,123,0.12): selected rows, config highlight, current rank.
  static const Color greenTint = Color(0x1F2FD67B);

  /// rgba(255,159,10,0.09) fill + 0.32 hairline: InfoNote / TiltBanner.
  static const Color orangeTint = Color(0x17FF9F0A);
  static const Color orangeHairline = Color(0x52FF9F0A);

  /// Glass hairline: 1px white @ 8%.
  static const Color glassHairline = Color(0x14FFFFFF);
}

/// DojiRadius — chip 10 · card 16 · sheet 24 · pill full.
abstract final class DojiRadius {
  static const double chip = 10;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

/// DojiSpace — 4pt grid. Touch targets ≥ 44, screen margin 20 (Android 22).
abstract final class DojiSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;

  static const double screenMargin = 20;
  static const double screenMarginAndroid = 22;

  /// iOS 44pt. Android uses 48dp (see [DojiTokens.minTarget]).
  static const double minTarget = 44;
  static const double minTargetAndroid = 48;
}

/// DojiGlass — fill elevated @ 60%, blur 24–30, saturate 1.4, hairline 1px white @ 8%.
abstract final class DojiGlass {
  static const double fillOpacity = 0.6;
  static const double blur = 28;
  static const double saturate = 1.4;
}

/// Theme-dependent tokens, exposed through [ThemeData.extension].
///
/// Radii and spacing are theme-independent and live in [DojiRadius] /
/// [DojiSpace]; colours live here so the stubbed light theme can swap them.
@immutable
class DojiTokens extends ThemeExtension<DojiTokens> {
  const DojiTokens({
    required this.bg,
    required this.elevated1,
    required this.elevated2,
    required this.separator,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.tilt,
    required this.accentTint,
    required this.tiltTint,
    required this.tiltHairline,
    required this.glassHairline,
    required this.grid,
    required this.minTarget,
  });

  final Color bg;
  final Color elevated1;
  final Color elevated2;
  final Color separator;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color tilt;
  final Color accentTint;
  final Color tiltTint;
  final Color tiltHairline;
  final Color glassHairline;
  final List<Color> grid;

  /// 44pt on iOS/desktop, 48dp on Android.
  final double minTarget;

  static const DojiTokens dark = DojiTokens(
    bg: DojiColors.bg,
    elevated1: DojiColors.elevated1,
    elevated2: DojiColors.elevated2,
    separator: DojiColors.separator,
    divider: DojiColors.divider,
    textPrimary: DojiColors.textPrimary,
    textSecondary: DojiColors.textSecondary,
    textTertiary: DojiColors.textTertiary,
    accent: DojiColors.dojiGreen,
    tilt: DojiColors.tiltOrange,
    accentTint: DojiColors.greenTint,
    tiltTint: DojiColors.orangeTint,
    tiltHairline: DojiColors.orangeHairline,
    glassHairline: DojiColors.glassHairline,
    grid: DojiColors.grid,
    minTarget: DojiSpace.minTarget,
  );

  /// STUB — light mode is not designed yet. Only bg (bone) and the wordmark
  /// underscore (#1E6B3E on bone) come from the design system.
  static const DojiTokens lightStub = DojiTokens(
    bg: DojiColors.bone,
    elevated1: Color(0xFFFFFFFF),
    elevated2: Color(0xFFE9E6DD),
    separator: Color(0xFFD6D2C7),
    divider: Color(0xFFE2DED4),
    textPrimary: DojiColors.bg,
    textSecondary: Color(0xFF55565B),
    textTertiary: Color(0xFF6E6E73),
    accent: Color(0xFF1E6B3E),
    tilt: Color(0xFF9A5B00),
    accentTint: Color(0x1F1E6B3E),
    tiltTint: Color(0x179A5B00),
    tiltHairline: Color(0x529A5B00),
    glassHairline: Color(0x14000000),
    grid: DojiColors.grid,
    minTarget: DojiSpace.minTarget,
  );

  static DojiTokens of(BuildContext context) => Theme.of(context).extension<DojiTokens>() ?? dark;

  @override
  DojiTokens copyWith({double? minTarget}) => DojiTokens(
    bg: bg,
    elevated1: elevated1,
    elevated2: elevated2,
    separator: separator,
    divider: divider,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    accent: accent,
    tilt: tilt,
    accentTint: accentTint,
    tiltTint: tiltTint,
    tiltHairline: tiltHairline,
    glassHairline: glassHairline,
    grid: grid,
    minTarget: minTarget ?? this.minTarget,
  );

  @override
  DojiTokens lerp(covariant DojiTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DojiTokens(
      bg: c(bg, other.bg),
      elevated1: c(elevated1, other.elevated1),
      elevated2: c(elevated2, other.elevated2),
      separator: c(separator, other.separator),
      divider: c(divider, other.divider),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      tilt: c(tilt, other.tilt),
      accentTint: c(accentTint, other.accentTint),
      tiltTint: c(tiltTint, other.tiltTint),
      tiltHairline: c(tiltHairline, other.tiltHairline),
      glassHairline: c(glassHairline, other.glassHairline),
      grid: [for (var i = 0; i < grid.length; i++) c(grid[i], other.grid[i])],
      minTarget: t < 0.5 ? minTarget : other.minTarget,
    );
  }
}

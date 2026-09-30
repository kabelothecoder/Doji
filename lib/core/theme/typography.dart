// DojiType — design system section 03 "Type", plus the onboarding sizes from
// design/handoff/Doji Onboarding.dc.html. Every style scales with textScaler.
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class DojiFonts {
  static const String sans = 'Geist';
  static const String mono = 'GeistMono';

  /// Numbers always use tabular figures so values don't jitter as they change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Letter-spacing in the handoff is given in em; Flutter wants logical px.
double _em(double em, double size) => em * size;

TextStyle _sans(double size, FontWeight w, {double track = 0, double? height, Color? color}) => TextStyle(
  fontFamily: DojiFonts.sans,
  fontSize: size,
  fontWeight: w,
  letterSpacing: _em(track, size),
  height: height,
  color: color ?? DojiColors.textPrimary,
  fontFeatures: DojiFonts.tabular,
);

TextStyle _mono(double size, FontWeight w, {double track = 0, double? height, Color? color}) => TextStyle(
  fontFamily: DojiFonts.mono,
  fontSize: size,
  fontWeight: w,
  letterSpacing: _em(track, size),
  height: height,
  color: color ?? DojiColors.textPrimary,
  fontFeatures: DojiFonts.tabular,
);

abstract final class DojiType {
  // --- Design system scale -------------------------------------------------
  /// Geist 600 · 56 / -3.5%
  static final display = _sans(56, FontWeight.w600, track: -0.035, height: 1.02);

  /// Geist 600 · 34 / -3%
  static final largeTitle = _sans(34, FontWeight.w600, track: -0.03, height: 1.08);

  /// Geist 600 · 28 / -2.5%
  static final title = _sans(28, FontWeight.w600, track: -0.025, height: 1.1);

  /// Geist 600 · 20 / -1%
  static final headline = _sans(20, FontWeight.w600, track: -0.01, height: 1.2);

  /// Geist 400 · 17 / 0
  static final body = _sans(17, FontWeight.w400, height: 1.45);

  /// Geist 400 · 15 / 0 · secondary
  static final callout = _sans(15, FontWeight.w400, height: 1.45, color: DojiColors.textSecondary);

  /// Mono 500 · 56 / -4%
  static final score = _mono(56, FontWeight.w500, track: -0.04, height: 1);

  /// Mono 500 · 17 / 0
  static final data = _mono(17, FontWeight.w500);

  /// Mono 400 · 15 / 1.6
  static final aiOutput = _mono(15, FontWeight.w400, height: 1.6);

  /// Mono 500 · 12 / +6% caps. Callers upper-case the string themselves.
  static final label = _mono(12, FontWeight.w500, track: 0.06, color: DojiColors.textSecondary);

  // --- Onboarding (handoff) --------------------------------------------------
  /// Doji's typed question. Mono 500 · 24 / 1.3 / -1%.
  static final question = _mono(24, FontWeight.w500, track: -0.01, height: 1.3);

  /// Windows question. Mono 500 · 36 / 1.2 / -1.5%.
  static final questionWide = _mono(36, FontWeight.w500, track: -0.015, height: 1.2);

  /// Doji's short reply above the question. Mono 400 · 15 / 1.55 · secondary.
  static final reply = _mono(15, FontWeight.w400, height: 1.55, color: DojiColors.textSecondary);
  static final replyWide = _mono(17, FontWeight.w400, height: 1.55, color: DojiColors.textSecondary);

  /// Boot lines. Mono 400 · 15 / 1.6 · secondary.
  static final terminal = _mono(15, FontWeight.w400, height: 1.6, color: DojiColors.textSecondary);

  /// "hey. i'm doji." Geist 600 · 44 / -3.5%.
  static final hero = _sans(44, FontWeight.w600, track: -0.035, height: 1.05);

  /// Manifesto. Geist 600 · 52 / -4%.
  static final manifesto = _sans(52, FontWeight.w600, track: -0.04, height: 1.02);

  /// Pledge headline. Geist 600 · 40 / -3.5%.
  static final pledge = _sans(40, FontWeight.w600, track: -0.035, height: 1.05);

  /// Subtitle under hero lines. Geist 400 · 19.
  static final heroSub = _sans(19, FontWeight.w400, height: 1.45, color: DojiColors.textSecondary);

  /// Buttons. Geist 600 · 17.
  static final button = _sans(17, FontWeight.w600);

  /// Choice tiles. Geist 500 · 17.
  static final choice = _sans(17, FontWeight.w500);

  /// Multi chips. Geist 500 · 16 (mono variant for symbols).
  static final chip = _sans(16, FontWeight.w500);
  static final chipMono = _mono(16, FontWeight.w500);

  /// Text answers. Geist 500 · 22.
  static final answer = _sans(22, FontWeight.w500);

  /// profile.doji lines. Mono 400 · 13 / 1.4 (14 on the Windows pane).
  static final config = _mono(13, FontWeight.w400, height: 1.4);
  static final configWide = _mono(14, FontWeight.w400, height: 1.4);

  /// Key hints and small status. Mono 400 · 12 · secondary.
  static final hint = _mono(12, FontWeight.w400, color: DojiColors.textSecondary);

  /// Wordmark. Mono 700 · -2%. Size is set by DojiWordmark.
  static final wordmark = _mono(18, FontWeight.w700, track: -0.02, height: 1);
}

/// Material text theme mapped onto DojiType so stock widgets inherit Geist.
TextTheme dojiTextTheme() => TextTheme(
  displayLarge: DojiType.display,
  headlineLarge: DojiType.largeTitle,
  headlineMedium: DojiType.title,
  titleLarge: DojiType.headline,
  titleMedium: DojiType.choice,
  bodyLarge: DojiType.body,
  bodyMedium: DojiType.callout.copyWith(color: DojiColors.textPrimary),
  bodySmall: DojiType.callout,
  labelLarge: DojiType.button,
  labelMedium: DojiType.data,
  labelSmall: DojiType.label,
);

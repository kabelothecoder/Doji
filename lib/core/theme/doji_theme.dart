import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Dark-first theme ("Apple premium × terminal"). Stock Material widgets are
/// tinted to the tokens so anything we did not wrap still looks like doji.
ThemeData dojiDarkTheme({TargetPlatform? platform}) {
  final isAndroid = (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  final tokens = DojiTokens.dark.copyWith(
    minTarget: isAndroid ? DojiSpace.minTargetAndroid : DojiSpace.minTarget,
  );
  const scheme = ColorScheme.dark(
    surface: DojiColors.bg,
    onSurface: DojiColors.textPrimary,
    surfaceContainerLowest: DojiColors.bg,
    surfaceContainerLow: DojiColors.elevated1,
    surfaceContainer: DojiColors.elevated1,
    surfaceContainerHigh: DojiColors.elevated2,
    surfaceContainerHighest: DojiColors.elevated2,
    onSurfaceVariant: DojiColors.textSecondary,
    primary: DojiColors.dojiGreen,
    onPrimary: DojiColors.bg,
    secondary: DojiColors.textPrimary,
    onSecondary: DojiColors.bg,
    error: DojiColors.tiltOrange,
    onError: DojiColors.bg,
    outline: DojiColors.separator,
    outlineVariant: DojiColors.divider,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    platform: platform,
    colorScheme: scheme,
    scaffoldBackgroundColor: DojiColors.bg,
    canvasColor: DojiColors.bg,
    fontFamily: DojiFonts.sans,
    textTheme: dojiTextTheme(),
    extensions: [tokens],
    // Doji-green focus rings everywhere keyboard focus can land.
    focusColor: DojiColors.dojiGreen.withValues(alpha: 0.24),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: const Color(0x0AFFFFFF),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: DojiColors.dojiGreen,
      selectionColor: Color(0x552FD67B),
      selectionHandleColor: DojiColors.dojiGreen,
    ),
    iconTheme: const IconThemeData(color: DojiColors.textPrimary, size: 22),
    dividerTheme: const DividerThemeData(color: DojiColors.separator, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: DojiColors.elevated2,
        borderRadius: BorderRadius.circular(DojiRadius.chip),
        border: Border.all(color: DojiColors.separator),
      ),
      textStyle: DojiType.hint.copyWith(color: DojiColors.textPrimary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// STUB for a later slice. Only the bone background is designed.
ThemeData dojiLightThemeStub() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: DojiColors.bone,
  fontFamily: DojiFonts.sans,
  extensions: const [DojiTokens.lightStub],
);

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Design system: `DojiGlass` (Materials) — "fill elevated @ 60%, blur 24–30,
/// saturate 1.4, hairline 1px white @ 8%. BackdropFilter + ClipRRect."
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = DojiRadius.card,
    this.blur = DojiGlass.blur,
    this.tint = DojiColors.elevated1,
    this.fillOpacity = DojiGlass.fillOpacity,
    this.padding,
    this.circle = false,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color tint;
  final double fillOpacity;
  final EdgeInsetsGeometry? padding;
  final bool circle;

  static List<double> _saturate(double s) => [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final filter = ui.ImageFilter.compose(
      outer: ColorFilter.matrix(_saturate(DojiGlass.saturate)),
      inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
    );
    final decoration = BoxDecoration(
      color: tint.withValues(alpha: fillOpacity),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
      border: Border.all(color: DojiColors.glassHairline),
    );
    final content = BackdropFilter(
      filter: filter,
      child: DecoratedBox(
        decoration: decoration,
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    return circle
        ? ClipOval(child: content)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
  }
}

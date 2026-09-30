import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Brand assets. Both files are coded stand-ins until the real SVGs arrive
/// (see design/SOURCE.md › missing). Swap the files; no code changes needed.
abstract final class DojiBrandAssets {
  static const appIcon = 'assets/svg/doji-app-icon.svg';
  static const symbol = 'assets/svg/doji-symbol.svg';

  /// Warm the SVG cache so the icon paints on the first frame after the
  /// native splash hands over.
  static Future<void> precache() async {
    for (final path in [appIcon, symbol]) {
      final loader = SvgAssetLoader(path);
      await svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
    }
  }
}

/// Design system: App icon (Brand), shown as the rounded tile from handoff S0:
/// radius 26/112 and an inset 1px white-8% hairline.
class DojiAppIcon extends StatelessWidget {
  const DojiAppIcon({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 26 / 112);
    return Semantics(
      label: 'doji app icon',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: DojiColors.glassHairline),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SvgPicture.asset(
              DojiBrandAssets.appIcon,
              width: size,
              height: size,
              excludeFromSemantics: true,
              placeholderBuilder: (_) => const ColoredBox(color: DojiColors.elevated1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Design system: `DojiSymbol` (Brand) — doji candle and cursor block.
class DojiSymbol extends StatelessWidget {
  const DojiSymbol({super.key, this.width = 44, this.monoColor});

  final double width;

  /// Single-colour variant (e.g. all doji-green on the app-icon previews).
  final Color? monoColor;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    DojiBrandAssets.symbol,
    width: width,
    height: width * 28 / 44,
    semanticsLabel: 'doji symbol',
    colorFilter: monoColor == null ? null : ColorFilter.mode(monoColor!, BlendMode.srcIn),
  );
}

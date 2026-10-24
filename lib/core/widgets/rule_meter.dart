import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: `RuleMeter` (Home spec): used vs limit for trades and daily
/// loss. The bar and the number turn tilt-orange from [warnAt] of the limit;
/// the numbers always say where you are, so colour is never the only signal.
class RuleMeter extends StatelessWidget {
  const RuleMeter({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.unit = '',
    this.warnAt = 0.6,
  });

  final String label;
  final num used;
  final num limit;

  /// '' for counts, '%' for account percent.
  final String unit;
  final double warnAt;

  static String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final fraction = limit <= 0 ? 0.0 : (used / limit).clamp(0, 1).toDouble();
    final warn = fraction >= warnAt;
    final value = '${_n(used)}$unit / ${_n(limit)}$unit';
    final color = warn ? DojiColors.tiltOrange : DojiColors.dojiGreen;
    return Semantics(
      container: true,
      label: '$label, $value${warn ? ', near the limit' : ''}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: DojiType.callout.copyWith(fontSize: 14, color: DojiColors.textPrimary),
                  ),
                ),
                Text(value, style: DojiType.config.copyWith(color: warn ? color : DojiColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: DojiColors.elevated2,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: `DojiSlider` (intensity) — 6px track in separator grey,
/// white fill, 28px white thumb. "Neutral fill: intensity is not good or bad."
/// Used here for a custom risk value.
class DojiSlider extends StatelessWidget {
  const DojiSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
    this.showTicks = false,
    this.compact = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double v)? format;
  final bool showTicks;

  /// Track only: the value is already shown elsewhere (e.g. on a chip).
  final bool compact;

  String _fmt(double v) => format?.call(v) ?? v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(label, style: DojiType.label.copyWith(letterSpacing: 0.5))),
              Text(_fmt(value), style: DojiType.data.copyWith(fontSize: 28)),
            ],
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: DojiColors.textPrimary,
            inactiveTrackColor: DojiColors.separator,
            thumbColor: DojiColors.textPrimary,
            overlayColor: DojiColors.dojiGreen.withValues(alpha: 0.16),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 4),
            trackShape: const RoundedRectSliderTrackShape(),
            valueIndicatorColor: DojiColors.elevated2,
            valueIndicatorTextStyle: DojiType.hint.copyWith(color: DojiColors.textPrimary),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: SizedBox(
            height: 44,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: _fmt(value),
              semanticFormatterCallback: (v) => '$label ${_fmt(v)}',
              onChanged: onChanged,
            ),
          ),
        ),
        if (showTicks && divisions != null)
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i <= divisions!; i++)
                  Text(_fmt(min + (max - min) * i / divisions!), style: DojiType.hint.copyWith(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

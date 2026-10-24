import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../domain/candle.dart';

/// The timeframe control on design system `ChartContainer`: a segmented row
/// on elevated-2, the selected one lifted to separator grey. Each segment is
/// a full touch target (the handoff draws 32; doji's minimum is 44).
class TimeframeTabs extends StatelessWidget {
  const TimeframeTabs({super.key, required this.selected, required this.onChanged});

  final Timeframe selected;
  final ValueChanged<Timeframe> onChanged;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return Semantics(
      container: true,
      label: 'timeframe',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            for (final tf in Timeframe.values)
              Expanded(
                child: DojiPressable(
                  onPressed: () => onChanged(tf),
                  borderRadius: BorderRadius.circular(9),
                  selected: tf == selected,
                  inMutuallyExclusiveGroup: true,
                  activateOnEnter: false,
                  semanticLabel: '${tf.spoken} chart',
                  child: Container(
                    constraints: BoxConstraints(minHeight: target),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tf == selected ? DojiColors.separator : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      tf.label,
                      maxLines: 1,
                      style: DojiType.data.copyWith(
                        fontSize: 13,
                        color: tf == selected ? DojiColors.textPrimary : DojiColors.textSecondary,
                      ),
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

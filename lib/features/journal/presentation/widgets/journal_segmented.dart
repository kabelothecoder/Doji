import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';

/// A pill-shaped segmented control (period, R / money, plan followed).
/// Selected = lifted fill; the selection is also in the semantics.
class JournalSegmented<T> extends StatelessWidget {
  const JournalSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.groupLabel,
    this.semanticOf,
    this.mono = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  /// "period", "show results in".
  final String groupLabel;

  /// Spoken label for one value ("show in R").
  final String Function(T)? semanticOf;
  final bool mono;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: groupLabel,
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            Flexible(
              child: DojiPressable(
                onPressed: () => onChanged(v),
                borderRadius: BorderRadius.circular(8),
                selected: v == selected,
                inMutuallyExclusiveGroup: true,
                semanticLabel: semanticOf?.call(v) ?? labelOf(v),
                activateOnEnter: false,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? DojiColors.separator : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labelOf(v),
                    maxLines: 1,
                    style: (mono ? DojiType.data : DojiType.chip).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: v == selected ? DojiColors.textPrimary : DojiColors.textSecondary,
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

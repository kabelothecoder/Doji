import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';

/// Handoff 1b's suggested questions under the brief ("why is this
/// waiting?"): outlined, mono, radius 10. At least a full touch target tall
/// (the handoff draws 36).
class FollowUpChip extends StatelessWidget {
  const FollowUpChip({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onPressed,
    semanticLabel: 'ask: $label',
    borderRadius: BorderRadius.circular(DojiRadius.chip),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DojiRadius.chip),
        border: Border.all(color: DojiColors.separator),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DojiTokens.of(context).minTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(label, style: DojiType.config.copyWith(color: DojiColors.textPrimary)),
          ),
        ),
      ),
    ),
  );
}

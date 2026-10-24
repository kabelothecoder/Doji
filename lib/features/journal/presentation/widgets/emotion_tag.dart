import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/trade.dart';

/// Doji Trade Journal › `EmotionTag`: "before anxious 7 → after angry 8".
/// Intensity is a number, never colour. Shows only the sides that were set.
class EmotionTag extends StatelessWidget {
  const EmotionTag({super.key, required this.before, required this.after});

  final TradeEmotion? before;
  final TradeEmotion? after;

  @override
  Widget build(BuildContext context) {
    if (before == null && after == null) return const SizedBox.shrink();
    Widget pill(String when, TradeEmotion e) => Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DojiRadius.pill),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(when, style: DojiType.hint.copyWith(fontSize: 11)),
          const SizedBox(width: 6),
          Text(e.label, style: DojiType.chip.copyWith(fontSize: 13, fontWeight: FontWeight.w400)),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: [
        if (before != null) 'before the trade: ${before!.name}, ${before!.intensity} of 10',
        if (after != null) 'after the trade: ${after!.name}, ${after!.intensity} of 10',
      ].join('. '),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (before != null) pill('before', before!),
            if (before != null && after != null)
              const Icon(Icons.arrow_forward_rounded, size: 18, color: DojiColors.textSecondary),
            if (after != null) pill('after', after!),
          ],
        ),
      ),
    );
  }
}

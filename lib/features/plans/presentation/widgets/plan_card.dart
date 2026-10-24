import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_animated_size.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../domain/plans.dart';
import 'recommended_badge.dart';

/// Design system: `PlanCard` (Doji Plans spec). One plan row: name, price and
/// ZAR price; open, it adds the why line (recommended only) and the includes.
///
/// Radius 16, min height 60, border separator → green 55% when selected. The
/// radio shape and border carry the selection, never colour alone.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.period,
    required this.selected,
    required this.expanded,
    required this.recommended,
    required this.onTap,
    this.reason,
  });

  final Plan plan;
  final BillingPeriod period;
  final bool selected;
  final bool expanded;
  final bool recommended;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DojiRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: radius,
        border: Border.all(color: selected ? const Color(0x8C2FD67B) : DojiColors.separator),
      ),
      child: DojiAnimatedSize(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DojiPressable(
              onPressed: onTap,
              borderRadius: radius,
              checked: selected,
              inMutuallyExclusiveGroup: true,
              semanticLabel:
                  '${plan.name}, ${plan.usd(period)}, ${plan.zar(period)}${recommended ? ', recommended' : ''}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _Radio(on: selected),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(plan.name, style: DojiType.body.copyWith(fontWeight: FontWeight.w600)),
                            if (recommended) const RecommendedBadge(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.usd(period),
                            style: DojiType.callout.copyWith(
                              fontFamily: DojiFonts.mono,
                              color: DojiColors.textPrimary,
                            ),
                          ),
                          Text(plan.zar(period), style: DojiType.hint),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recommended && reason != null && reason!.isNotEmpty) ...[
                      Text.rich(
                        TextSpan(
                          style: DojiType.callout.copyWith(color: DojiColors.textPrimary, height: 1.4),
                          children: [
                            TextSpan(
                              text: 'why · ',
                              style: DojiType.config.copyWith(color: DojiColors.dojiGreen),
                            ),
                            TextSpan(text: reason),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final line in plan.includes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(
                              child: Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.check_rounded, size: 16, color: DojiColors.dojiGreen),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(line, style: DojiType.callout.copyWith(fontSize: 14, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: on ? DojiColors.dojiGreen : const Color(0xFF4A4E55), width: 2),
    ),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? DojiColors.dojiGreen : Colors.transparent,
      ),
    ),
  );
}

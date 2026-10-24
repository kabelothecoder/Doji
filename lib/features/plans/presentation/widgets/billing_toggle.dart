import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../domain/plans.dart';

/// Design system: `BillingToggle` (Doji Plans spec). Monthly / annual
/// segmented control, 44 total height, radius 12 outer / 9 thumb, announced
/// as a radio group. Switching updates every price, the timeline and the
/// terms line.
class BillingToggle extends StatelessWidget {
  const BillingToggle({super.key, required this.value, required this.onChanged});

  final BillingPeriod value;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final minHeight = DojiTokens.of(context).minTarget;
    return Semantics(
      container: true,
      label: 'billing period',
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DojiColors.separator),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Segment(
                  label: 'monthly',
                  on: value == BillingPeriod.monthly,
                  onTap: () => onChanged(BillingPeriod.monthly),
                ),
              ),
              Expanded(
                child: _Segment(
                  label: 'annual',
                  note: annualNote,
                  on: value == BillingPeriod.annual,
                  onTap: () => onChanged(BillingPeriod.annual),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, required this.onTap, this.note});

  final String label;
  final String? note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9);
    return DojiPressable(
      onPressed: onTap,
      borderRadius: radius,
      checked: on,
      inMutuallyExclusiveGroup: true,
      semanticLabel: note == null ? label : '$label, $note',
      pressedScale: 1,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: on ? DojiColors.separator : Colors.transparent,
          borderRadius: radius,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              label,
              style: DojiType.callout.copyWith(
                fontWeight: FontWeight.w500,
                color: on ? DojiColors.textPrimary : DojiColors.textSecondary,
              ),
            ),
            if (note != null) Text(note!, style: DojiType.hint.copyWith(color: DojiColors.dojiGreen)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/plans.dart';

/// Design system: `TrialTimeline` (Doji Plans spec). today: full access →
/// day 2: we remind you → day 3: trial ends, price starts. The reminder line
/// is fixed copy. Vertical on phones, horizontal on Windows; the caller hides
/// it when free is selected.
class TrialTimeline extends StatelessWidget {
  const TrialTimeline({super.key, required this.planName, required this.price, this.axis = Axis.vertical});

  final String planName;
  final String price;
  final Axis axis;

  static const reminder = "we'll remind you a day before your trial ends.";

  List<(String, String)> get _steps => [
    ('today', 'full access to $planName'),
    ('day 2', 'we remind you'),
    ('day $trialDays', 'trial ends, $price starts'),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Semantics(
      container: true,
      label: 'how the trial works: ${steps.map((s) => '${s.$1}, ${s.$2}').join('. ')}',
      child: ExcludeSemantics(
        child: axis == Axis.vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 12,
                            child: Column(
                              children: [
                                const SizedBox(height: 4),
                                _Dot(filled: i == 0),
                                Expanded(
                                  child: Container(
                                    width: 1,
                                    color: i == steps.length - 1 ? Colors.transparent : DojiColors.separator,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(steps[i].$1, style: DojiType.hint.copyWith(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(
                                    steps[i].$2,
                                    style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Dot(filled: i == 0),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: i == steps.length - 1 ? Colors.transparent : DojiColors.separator,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(steps[i].$1, style: DojiType.hint.copyWith(fontSize: 12)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              steps[i].$2,
                              style: DojiType.callout.copyWith(fontSize: 14, color: DojiColors.textPrimary),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? DojiColors.dojiGreen : DojiColors.bg,
      border: Border.all(color: filled ? DojiColors.dojiGreen : DojiColors.textSecondary, width: 2),
    ),
  );
}

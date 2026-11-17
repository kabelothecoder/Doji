import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/strategy_state.dart';

/// Design `StrategyStateBadge` (Doji Core Tabs › 11 spec): waiting = ring,
/// forming = half fill, conditions met = full fill, always with the word.
/// Green rings for met and forming, grey for waiting.
class StrategyStateBadge extends StatelessWidget {
  const StrategyStateBadge({super.key, required this.state});

  final StrategyState state;

  @override
  Widget build(BuildContext context) {
    final on = state != StrategyState.waiting;
    final ring = on ? DojiColors.dojiGreen : DojiColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 2),
          ),
          child: ClipOval(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: FractionallySizedBox(
                widthFactor: switch (state) {
                  StrategyState.met => 1,
                  StrategyState.forming => 0.5,
                  StrategyState.waiting => 0,
                },
                heightFactor: 1,
                child: ColoredBox(color: ring),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            state.label,
            style: DojiType.hint.copyWith(color: on ? DojiColors.textPrimary : DojiColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

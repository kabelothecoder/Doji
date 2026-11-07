import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../backtest/presentation/widgets/practice_widgets.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../data/gym_repository.dart';

/// The gym: daily drills (2–5 minutes) and replay practice, both scored on
/// process. Practice days show on Home's grid apart from trading days.
class GymScreen extends ConsumerWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(drillStreakProvider);
    final now = clock.now();
    final doneToday = ref.watch(practiceDaysProvider).contains(DateTime(now.year, now.month, now.day));
    final instruments = [
      for (final s in ref.watch(marketsProfileProvider).instruments)
        if (instrumentBySymbol(s) != null) s,
    ];
    final practices = [
      for (final e in ref.watch(gymProvider))
        if (e.kind == GymEntryKind.practice) e,
    ].reversed.take(5).toList();
    return PracticeScaffold(
      title: 'gym',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.me),
      children: [
        Text(
          'practice following your plan. scored on process, never on the result.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 16),
        PracticeCard(
          label: 'daily drills',
          children: [
            Text(
              doneToday
                  ? "today's set is done."
                  : 'spot your setup, place the stop, size the trade, and the day after losses.',
              style: DojiType.callout,
            ),
            HintText(
              'drill streak: $streak ${streak == 1 ? 'day' : 'days'}. practice days, not trading days.',
            ),
            const SizedBox(height: 12),
            DojiButton(
              label: doneToday ? 'practise again' : "start today's drills",
              size: DojiButtonSize.regular,
              onPressed: () => context.push(Routes.drills),
            ),
          ],
        ),
        PracticeCard(
          label: 'replay practice',
          children: [
            Text(
              'a random past session of your instruments. take or skip setups by your rules.',
              style: DojiType.callout,
            ),
            const SizedBox(height: 12),
            if (instruments.isEmpty)
              const HintText('add instruments from markets first.')
            else
              DojiButton(
                label: 'start a practice',
                variant: DojiButtonVariant.secondary,
                size: DojiButtonSize.regular,
                onPressed: () => context.push(
                  Routes.replay(
                    instruments[Random(now.microsecondsSinceEpoch).nextInt(instruments.length)],
                    gym: true,
                  ),
                ),
              ),
            for (final p in practices)
              HintText(
                '${fmtDate(p.at)} · ${p.symbol == null ? '' : instrumentLabel(p.symbol!)} · process grade ${p.grade ?? '-'}',
              ),
          ],
        ),
      ],
    );
  }
}

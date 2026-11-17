import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../gym/data/gym_repository.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import 'widgets/practice_widgets.dart';

/// The me tab: practice. Backtest the strategy on history, replay past
/// sessions bar by bar, and the gym. No design file (design/SOURCE.md ›
/// Missing): built from `core/widgets/`. Account and settings stay one tap away.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(marketsProfileProvider).activeAccount;
    final streak = ref.watch(drillStreakProvider);
    return PracticeScaffold(
      title: 'practice',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.me),
      children: [
        Text(
          account == null
              ? 'no account yet.'
              : '${account.name} · strategy version ${account.strategyVersion}',
          style: DojiType.callout,
        ),
        const HintText('a safe place to test your strategy on history and to practise following it.'),
        const SizedBox(height: 16),
        _Entry(
          title: 'backtest',
          body: 'run your measurable conditions over past prices, then try one change at a time.',
          onTap: () => context.go(Routes.meBacktest),
        ),
        _Entry(
          title: 'replay',
          body: 'a past session bar by bar, future hidden. draw and place positions as on the chart.',
          onTap: () => context.go(Routes.meReplays),
        ),
        _Entry(
          title: 'gym',
          body: streak == 0
              ? 'daily drills and replay practice, scored on process.'
              : 'daily drills and replay practice, scored on process. drill streak: $streak ${streak == 1 ? 'day' : 'days'}.',
          onTap: () => context.go(Routes.meGym),
        ),
        const SizedBox(height: 12),
        DojiButton(
          label: 'account and settings',
          variant: DojiButtonVariant.outline,
          size: DojiButtonSize.regular,
          onPressed: () => context.push(Routes.settings),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.title, required this.body, required this.onTap});

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PracticeCard(
    children: [
      Text(title, style: DojiType.headline),
      const SizedBox(height: 4),
      Text(body, style: DojiType.callout),
      const SizedBox(height: 12),
      DojiButton(
        label: 'open $title',
        variant: DojiButtonVariant.secondary,
        size: DojiButtonSize.regular,
        onPressed: onTap,
      ),
    ],
  );
}

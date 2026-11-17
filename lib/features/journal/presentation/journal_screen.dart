import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/widgets/home_card.dart';
import '../domain/journal_stats.dart';
import '../../analyst/presentation/weekly_review_card.dart';
import 'journal_controller.dart';
import 'widgets/dashed_border.dart';
import 'widgets/equity_curve.dart';
import 'widgets/journal_page.dart';
import 'widgets/journal_segmented.dart';
import 'widgets/journal_stat_row.dart';
import 'widgets/result_heatmap.dart';
import 'widgets/trade_row.dart';

/// Insights unlock at this many trades (patterns from a handful are noise).
const int kInsightsFromTrades = 20;

/// The journal tab (Doji Trade Journal › journal home): stats, equity curve,
/// calendar and the latest trades. Insights, the weekly review, CSV import and
/// the Windows workspace are separate slices.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(journalControllerProvider);
    final view = ref.watch(journalViewProvider);
    final stats = ref.watch(journalStatsProvider);
    final currency = ref.watch(accountCurrencyProvider);
    final notifier = ref.read(journalViewProvider.notifier);
    final now = clock.now();
    final accountTrades = ref.watch(activeAccountTradesProvider).length;

    final header = Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text('journal', style: DojiType.title)),
        ),
        Transform.translate(
          offset: const Offset(6, 0),
          child: DojiIconButton(
            icon: Icons.add_rounded,
            semanticLabel: 'add a trade',
            outlined: false,
            background: DojiColors.textPrimary,
            foreground: DojiColors.bg,
            iconSize: 24,
            onPressed: () => unawaited(context.push(Routes.addTrade)),
          ),
        ),
      ],
    );

    if (all.isEmpty) {
      return JournalPage(
        children: [
          header,
          const TerminalLine('no trades yet. add your first one.', cursor: true, liveRegion: false),
          Text(
            'every trade gets a process grade, and after $kInsightsFromTrades trades doji starts finding the '
            'patterns in them.',
            style: DojiType.callout,
          ),
          _AddTile(
            icon: Icons.edit_note_rounded,
            title: 'add a trade manually',
            sub: 'one trade · about a minute',
            onTap: () => unawaited(context.push(Routes.addTrade)),
          ),
          Text(
            'connecting an account and importing a csv arrive in a later build.',
            style: DojiType.hint.copyWith(fontSize: 12, height: 1.5),
          ),
        ],
      );
    }

    final recent = all.take(4).toList();
    return JournalPage(
      children: [
        header,
        TerminalLine(
          '${all.length} ${all.length == 1 ? 'trade' : 'trades'} · saved on this device',
          liveRegion: false,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            JournalSegmented<JournalPeriod>(
              values: JournalPeriod.values,
              selected: view.period,
              groupLabel: 'period',
              labelOf: (p) => p.label,
              semanticOf: (p) => 'period: ${p.label}',
              onChanged: notifier.setPeriod,
            ),
            JournalSegmented<ResultUnit>(
              values: ResultUnit.values,
              selected: view.unit,
              groupLabel: 'show results in',
              mono: true,
              labelOf: (u) => u == ResultUnit.r ? 'R' : currency.symbol,
              semanticOf: (u) => u == ResultUnit.r ? 'show results in R' : 'show results in money',
              onChanged: notifier.setUnit,
            ),
          ],
        ),
        if (all.length < kInsightsFromTrades) _TooFewBanner(count: all.length),
        JournalStatRow(stats: JournalStatRow.from(stats, currency.symbol)),
        EquityCurve(stats: stats, currencySymbol: currency.symbol),
        if (accountTrades < kInsightsFromTrades)
          _InsightsLocked(count: accountTrades)
        else ...[
          const WeeklyReviewCard(),
          DojiButton(
            label: 'ask the analyst',
            variant: DojiButtonVariant.outline,
            onPressed: () => unawaited(showAnalystChatSheet(context)),
          ),
        ],
        ResultHeatmap(
          month: now,
          today: now,
          days: calendarMonth(all, now, view.unit),
          unit: view.unit,
          currencySymbol: currency.symbol,
          selected: view.selectedDay,
          onSelect: notifier.selectDay,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: HomeEyebrow('RECENT TRADES')),
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: DojiButton(
                    label: 'all trades',
                    variant: DojiButtonVariant.ghost,
                    size: DojiButtonSize.small,
                    expand: false,
                    onPressed: () => unawaited(context.push(Routes.trades)),
                  ),
                ),
              ],
            ),
            for (final t in recent)
              TradeRow(
                trade: t,
                unit: view.unit,
                currencySymbol: currency.symbol,
                onTap: () => unawaited(context.push(Routes.tradeDetail(t.id))),
              ),
          ],
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.title, required this.sub, required this.onTap});

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onTap,
    borderRadius: BorderRadius.circular(DojiRadius.card),
    semanticLabel: '$title, $sub',
    child: Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.dojiGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: DojiColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sub, style: DojiType.hint),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: DojiColors.textSecondary),
        ],
      ),
    ),
  );
}

/// "[n]/20 trades. insights unlock at 20." with a terminal progress bar.
class _TooFewBanner extends StatelessWidget {
  const _TooFewBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => HomeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalLine(
          '$count/$kInsightsFromTrades trades. insights unlock at $kInsightsFromTrades.',
          tone: TerminalTone.primary,
          liveRegion: false,
        ),
        const SizedBox(height: 10),
        ProgressBarTerminal(fraction: count / kInsightsFromTrades, suffix: 'to insights'),
        const SizedBox(height: 10),
        Text(
          'patterns need data. until then you get grades, stats and the calendar.',
          style: DojiType.callout.copyWith(fontSize: 13),
        ),
      ],
    ),
  );
}

class _InsightsLocked extends StatelessWidget {
  const _InsightsLocked({required this.count});

  /// Trades on the active account.
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const HomeEyebrow('INSIGHTS'),
      const SizedBox(height: 10),
      DashedBorder(
        radius: DojiRadius.card,
        color: const Color(0xFF3A3D42),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: DojiColors.textSecondary),
                const SizedBox(width: 8),
                Text('locked until $kInsightsFromTrades trades', style: DojiType.hint.copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'the analyst, the weekly review and its questions read $kInsightsFromTrades trades before they say '
              'anything; this account has $count. patterns from a handful of trades are mostly noise.',
              style: DojiType.callout.copyWith(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}

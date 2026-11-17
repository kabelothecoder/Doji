import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../backtest/data/backtest_repository.dart';
import '../../backtest/domain/backtest.dart';
import '../../backtest/domain/fills.dart';
import '../../backtest/presentation/backtest_controller.dart';
import '../../backtest/presentation/widgets/practice_widgets.dart';
import '../../chart/presentation/chart_screen.dart';
import '../../gym/data/gym_repository.dart';
import '../../gym/domain/gym.dart';
import '../../history/history.dart';
import '../../markets/data/routed_market_data.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/market_data.dart';
import '../../markets/domain/time_zones.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import 'replay_controller.dart';

/// A replay (manual backtest) or, with [gym], a scored replay practice on a
/// random past session. The slice 04 chart, fed from history bar by bar:
/// bars ahead are never handed to it. Position boxes fill on the bars as they
/// are revealed and are saved to a [BacktestSession].
///
/// Keys (Windows): N next bar, Space play / pause; the chart's own keys stay.
class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({super.key, required this.symbol, this.day, this.gym = false});

  final String symbol;

  /// UTC date. Null with [gym]: a random weekday of the last 45.
  final DateTime? day;
  final bool gym;

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  late final String _id = '${widget.gym ? 'gym' : 'replay'}-${clock.now().microsecondsSinceEpoch}';
  String? _error;
  bool _loading = true;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  static DateTime randomWeekday(DateTime now, Random rnd) {
    final today = DateTime.utc(now.year, now.month, now.day);
    while (true) {
      final d = today.subtract(Duration(days: 1 + rnd.nextInt(45)));
      if (d.weekday <= 5) return d;
    }
  }

  Future<void> _load() async {
    TimeZones.ensureInitialized();
    final profile = ref.read(marketsProfileProvider);
    final account = profile.activeAccount;
    final symbol = widget.symbol.toUpperCase();
    final tf = backtestTimeframe(account?.strategy);
    _day = widget.day ?? randomWeekday(clock.now().toUtc(), Random(clock.now().microsecondsSinceEpoch));
    try {
      final range = await ref
          .read(historyServiceProvider)
          .ensure(
            symbol,
            tf,
            from: _day.subtract(const Duration(days: 1)),
            to: _day.add(const Duration(days: 1)),
          );
      final bars = range.between(_day.subtract(const Duration(days: 1)), _day.add(const Duration(days: 1)));
      final tokyo = TradingSession.tokyo.openInstant(_day)!;
      final start = lowerBound(bars, tokyo);
      if (!mounted) return;
      if (start >= bars.length) {
        setState(() {
          _loading = false;
          _error = 'no prices on ${fmtDate(_day)} for ${instrumentLabel(symbol)}. pick another day.';
        });
        return;
      }
      ref
          .read(replayProvider(_id).notifier)
          .load(
            ReplaySetup(
              sessionId: _id,
              symbol: symbol,
              timeframe: tf,
              history: bars,
              startCursor: start,
              accountId: account?.id ?? 'none',
              strategyVersion: account?.strategyVersion ?? 1,
              kind: widget.gym ? BacktestKind.gym : BacktestKind.replay,
              source: ref.read(marketDataProvider).sourceOf(symbol),
              day: _day,
            ),
          );
      setState(() => _loading = false);
    } on FeedUnavailable {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'price feed not responding.';
        });
      }
    }
  }

  void _back() {
    ref.read(replayProvider(_id).notifier).pause();
    context.canPop() ? context.pop() : context.go(widget.gym ? Routes.meGym : Routes.meReplays);
  }

  Future<void> _finish(ReplayState s) async {
    final c = ref.read(replayProvider(_id).notifier)..pause();
    final profile = ref.read(marketsProfileProvider);
    final account = profile.activeAccount;
    // The day's own setups, measured on the whole day: for scoring only, after the practice.
    final tf = s.setup.timeframe;
    final result = runBacktest(
      BacktestInput(
        conditions: strategyConditions(account?.strategy),
        exits: account?.strategy?.exits ?? const ExitRules(),
        timeframe: tf,
        candles: {s.setup.symbol: s.setup.history},
        from: _day,
        to: _day.add(const Duration(days: 1)),
        traderSessions: profile.sessions,
        rules: account?.rules,
        dailyLossLimitPct: account?.strictestDailyLossPct,
      ),
    );
    final near = tf.duration * 3;
    final takes = [
      for (final t
          in s.tracks.values.where((t) => t.entered).toList()
            ..sort((a, b) => a.entryAt!.compareTo(b.entryAt!)))
        PracticeTake(
          entryAt: t.entryAt!,
          setupThere: result.trades.any((x) => x.entryAt.difference(t.entryAt!).abs() <= near),
          stopMoved: t.stopMoved,
        ),
    ];
    final score = scorePractice(
      takes: takes,
      setups: result.trades.length,
      maxTrades: account?.rules?.maxTradesPerDay,
    );
    await ref
        .read(gymProvider.notifier)
        .add(
          GymEntry(
            id: _id,
            at: clock.now().toUtc(),
            accountId: account?.id ?? 'none',
            kind: GymEntryKind.practice,
            grade: score.grade.letter,
            symbol: s.setup.symbol,
            notes: [
              for (final r in score.reasons) '${r.kept ? 'kept' : 'broken'}: ${r.text}',
              if (score.missed > 0) 'setups let pass: ${score.missed}',
            ],
          ),
        );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DojiColors.elevated2,
        title: Text('process grade ${score.grade.letter}', style: DojiType.headline),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('scored on how you followed your rules, never on the result.', style: DojiType.callout),
              const SizedBox(height: 10),
              for (final r in score.reasons)
                Text('${r.kept ? 'kept' : 'broken'} · ${r.text}', style: DojiType.callout),
              if (score.missed > 0)
                HintText(
                  '${score.missed} ${score.missed == 1 ? 'setup' : 'setups'} of your strategy went by. '
                  'letting one pass is never a mistake.',
                ),
              HintText('${result.trades.length} measured setups on ${fmtDate(_day)}.'),
            ],
          ),
        ),
        actions: [
          DojiButton(
            label: 'done',
            size: DojiButtonSize.small,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    if (mounted) _back();
    c.pause();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(replayProvider(_id));
    if (_loading || _error != null || s == null) {
      return PracticeScaffold(
        title: widget.gym ? 'replay practice' : 'replay',
        onBack: _back,
        children: [
          if (_error != null) ...[
            Text(_error!, style: DojiType.callout),
            const SizedBox(height: 12),
            DojiButton(
              label: 'try again',
              variant: DojiButtonVariant.outline,
              size: DojiButtonSize.regular,
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                unawaited(_load());
              },
            ),
          ] else
            const TerminalLine('loading history', cursor: true, liveRegion: true),
        ],
      );
    }
    final c = ref.read(replayProvider(_id).notifier);
    final reduced = DojiMotion.reduced(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): c.next,
        if (!reduced) const SingleActivator(LogicalKeyboardKey.space): () => s.playing ? c.pause() : c.play(),
      },
      child: ChartScreen(
        symbol: s.setup.symbol,
        replayId: _id,
        timeframe: s.setup.timeframe,
        replayBars: s.visible,
        source: s.setup.source,
        subtitle: '${widget.gym ? 'practice' : 'replay'} · ${fmtDate(_day)} · bars ahead hidden',
        footer: _Controls(
          state: s,
          controller: c,
          reduced: reduced,
          onFinish: widget.gym ? () => unawaited(_finish(s)) : null,
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller, required this.reduced, this.onFinish});

  final ReplayState state;
  final ReplayController controller;
  final bool reduced;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final trades = s.trades;
    final open = s.tracks.values.where((t) => t.entered && !t.closed).length;
    final waiting = s.tracks.values.where((t) => !t.entered).length;
    final closed = trades.where((t) => t.closed).toList();
    final total = closed.fold(0.0, (x, t) => x + t.r);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DojiButton(
                  label: 'next bar (N)',
                  semanticLabel: 'next bar',
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: s.atEnd ? null : controller.next,
                ),
                if (!reduced)
                  DojiButton(
                    label: s.playing ? 'pause' : 'play',
                    variant: DojiButtonVariant.secondary,
                    size: DojiButtonSize.small,
                    expand: false,
                    onPressed: s.atEnd ? null : (s.playing ? controller.pause : controller.play),
                  ),
                DojiButton(
                  label: 'jump to london open',
                  variant: DojiButtonVariant.outline,
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: s.atEnd ? null : () => controller.jumpTo(TradingSession.london),
                ),
                if (onFinish != null)
                  DojiButton(
                    label: 'finish practice',
                    variant: DojiButtonVariant.outline,
                    size: DojiButtonSize.small,
                    expand: false,
                    onPressed: onFinish,
                  ),
              ],
            ),
            if (!reduced) ...[
              const SizedBox(height: 8),
              ChipRow<int>(
                values: ReplayController.speeds,
                selected: s.speed,
                label: (n) => '$n bar${n == 1 ? '' : 's'}/s',
                onTap: controller.setSpeed,
              ),
            ],
            Semantics(
              liveRegion: true,
              child: HintText(
                '${s.atEnd ? 'end of the replay. ' : ''}positions: $waiting waiting · $open open · ${closed.length} closed'
                '${closed.isEmpty ? '' : ' · ${fmtR(total)}'}',
              ),
            ),
            const HintText(kSameBarRule),
          ],
        ),
      ),
    );
  }
}

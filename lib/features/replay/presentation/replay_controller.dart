import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/condition_eval.dart';
import '../../backtest/data/backtest_repository.dart';
import '../../backtest/domain/backtest.dart';
import '../../backtest/presentation/backtest_controller.dart';
import '../../chart/presentation/chart_controller.dart';
import '../../coach/domain/coach.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/london_break.dart';
import '../../markets/domain/market_data.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/sessions.dart';
import '../domain/replay.dart';

/// What a replay plays: one instrument's history from [startCursor] on.
class ReplaySetup {
  const ReplaySetup({
    required this.sessionId,
    required this.symbol,
    required this.timeframe,
    required this.history,
    required this.startCursor,
    required this.accountId,
    required this.strategyVersion,
    required this.kind,
    required this.source,
    required this.day,
  });

  final String sessionId;
  final String symbol;
  final Timeframe timeframe;

  /// The day before (context) and the replayed day, oldest first.
  final List<Candle> history;

  /// Bars shown when the replay starts (the context).
  final int startCursor;
  final String accountId;
  final int strategyVersion;
  final BacktestKind kind;
  final FeedSource source;

  /// The replayed day (UTC midnight).
  final DateTime day;

  ChartKey get chartKey => ChartKey(symbol, replayId: sessionId, timeframe: timeframe);
}

class ReplayState {
  const ReplayState({
    required this.setup,
    required this.cursor,
    this.playing = false,
    this.speed = 1,
    this.tracks = const {},
  });

  final ReplaySetup setup;
  final int cursor;
  final bool playing;

  /// Bars a second while playing.
  final int speed;
  final Map<String, PositionTrack> tracks;

  ReplayBarSource get source => ReplayBarSource(setup.history, cursor: cursor, source: setup.source);
  List<Candle> get visible => source.visible;
  bool get atEnd => cursor >= setup.history.length;

  List<BacktestTrade> get trades =>
      [for (final t in tracks.values) ?t.toTrade(setup.symbol)]
        ..sort((a, b) => a.entryAt.compareTo(b.entryAt));

  ReplayState copyWith({int? cursor, bool? playing, int? speed, Map<String, PositionTrack>? tracks}) =>
      ReplayState(
        setup: setup,
        cursor: cursor ?? this.cursor,
        playing: playing ?? this.playing,
        speed: speed ?? this.speed,
        tracks: tracks ?? this.tracks,
      );
}

/// Plays a replay bar by bar. Each revealed bar fills the trader's position
/// boxes ([revealBar]); the session is saved as it changes.
class ReplayController extends Notifier<ReplayState?> {
  ReplayController(this.id);

  final String id;
  Timer? _timer;

  static const speeds = [1, 2, 4, 8];

  @override
  ReplayState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void load(ReplaySetup setup) {
    state = ReplayState(setup: setup, cursor: setup.startCursor);
    _publishFacts();
  }

  /// Reveals the next bar. False at the end of the replay.
  bool next() {
    final s = state;
    if (s == null || s.atEnd) {
      pause();
      return false;
    }
    final bar = s.setup.history[s.cursor];
    final lastShown = s.cursor == 0
        ? bar.at.subtract(s.setup.timeframe.duration)
        : s.setup.history[s.cursor - 1].at;
    final drawings = ref.read(chartControllerProvider(s.setup.chartKey)).drawings;
    final tracks = revealBar(s.tracks, drawings, bar, lastShown: lastShown);
    state = s.copyWith(cursor: s.cursor + 1, tracks: tracks);
    _publishFacts();
    if (tracks.values.any((t) => t.entered)) unawaited(_save());
    return true;
  }

  void play() {
    final s = state;
    if (s == null || s.atEnd) return;
    state = s.copyWith(playing: true);
    _restart();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    final s = state;
    if (s != null && s.playing) state = s.copyWith(playing: false);
  }

  void setSpeed(int speed) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(speed: speed);
    if (s.playing) _restart();
  }

  void _restart() {
    _timer?.cancel();
    final speed = state?.speed ?? 1;
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ speed), (_) {
      if (!next()) pause();
    });
  }

  /// Reveals bars until [session] opens (each bar still fills the boxes on
  /// the way). False when it does not open again in this replay.
  bool jumpTo(TradingSession session) {
    final s = state;
    if (s == null || s.atEnd) return false;
    final from = s.setup.history[s.cursor].at;
    final open = session.nextOpenAfter(from.subtract(const Duration(seconds: 1)));
    if (open == null || !s.setup.history.any((b) => !b.at.isBefore(open))) return false;
    while (state != null && !state!.atEnd && state!.setup.history[state!.cursor].at.isBefore(open)) {
      next();
    }
    // The bar that opens the session is shown too.
    next();
    return true;
  }

  /// The conditions and the replayed day so far, for the pre-trade check and
  /// the co-pilot. Measured on the shown bars only.
  void _publishFacts() {
    final s = state;
    if (s == null) return;
    final shown = s.visible;
    if (shown.isEmpty) return;
    final tf = s.setup.timeframe;
    final now = shown.last.at.add(tf.duration);
    final profile = ref.read(marketsProfileProvider);
    final w = LondonBreak.windowFor(LondonBreak.lastTokyoOpen(now));
    final a = lowerBound(shown, w.tokyoOpen), b = lowerBound(shown, w.londonOpen);
    final lb = LondonBreak.measure(
      asian: shown.sublist(a, b),
      london: shown.sublist(b),
      tf: tf,
      now: now,
      londonOpen: w.londonOpen,
      londonClose: w.londonClose,
    );
    final risk = profile.rules?.riskPerTrade ?? 1;
    final day = [
      for (final t in s.trades)
        if (!t.entryAt.isBefore(w.tokyoOpen)) t,
    ];
    final closedPct = day.where((t) => t.closed).fold(0.0, (x, t) => x + t.r * risk);
    final limit = profile.activeAccount?.strictestDailyLossPct;
    final measured = measureConditions(
      strategyConditions(profile.strategy),
      ConditionFacts(
        now: now,
        marketOpen: true,
        traderSessions: profile.sessions,
        tradesToday: day.length,
        lossTodayPct: closedPct < 0 ? -closedPct : 0,
        maxTradesPerDay: profile.rules?.maxTradesPerDay,
        dailyLossLimitPct: limit,
        rangeBroke: lb.breakAt != null,
        closedBack: lb.retestAt != null,
        rangeOver: lb.londonOver,
        timeframeLabel: tf.label,
      ),
    );
    final base = CoachContext.from(profile, trades: const [], now: clock.now());
    var streak = 0;
    for (final t in day.reversed.where((t) => t.closed)) {
      if (t.r >= 0) break;
      streak++;
    }
    ref
        .read(chartFactsProvider(s.setup.sessionId).notifier)
        .set(
          ChartFacts(
            conditions: measured.conditions,
            coach: CoachContext(
              name: base.name,
              setup: base.setup,
              entry: base.entry,
              riskPerTradePct: base.riskPerTradePct,
              maxTradesPerDay: base.maxTradesPerDay,
              dailyLossLimitPct: base.dailyLossLimitPct,
              struggles: base.struggles,
              tradesToday: day.length,
              lossStreak: streak,
              lossTodayPct: closedPct < 0 ? -closedPct : 0,
            ),
          ),
        );
  }

  Future<void> _save() async {
    final s = state;
    if (s == null) return;
    final day = s.setup.day;
    await ref
        .read(backtestSessionsProvider.notifier)
        .upsert(
          BacktestSession(
            id: s.setup.sessionId,
            accountId: s.setup.accountId,
            strategyVersion: s.setup.strategyVersion,
            kind: s.setup.kind,
            symbols: [s.setup.symbol],
            timeframe: s.setup.timeframe,
            from: day,
            to: day.add(const Duration(days: 1)),
            createdAt: clock.now().toUtc(),
            trades: s.trades,
            label: s.setup.kind == BacktestKind.gym ? 'gym practice' : 'replay',
          ),
        );
  }
}

final replayProvider = NotifierProvider.autoDispose.family<ReplayController, ReplayState?, String>(
  ReplayController.new,
);

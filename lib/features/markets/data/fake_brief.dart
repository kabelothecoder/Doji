import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../onboarding/domain/sessions.dart';
import '../../onboarding/domain/user_zone.dart';
import '../domain/candle.dart';
import '../domain/instrument.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';
import '../domain/market_format.dart';
import '../domain/market_status.dart';
import '../domain/news.dart';
import '../domain/pair_brief.dart';
import '../domain/strategy_reading.dart';
import '../domain/time_zones.dart';
import 'routed_market_data.dart';
import 'sample_news_calendar.dart';

/// The brief, worked out on the device: conditions are measured (the
/// session clock, the journal, the sample candles, the sample calendar) and
/// the five sections are written from them in doji's voice. It reads the
/// trader's own strategy and rules back to them; it never says where price
/// will go or which way to trade.
///
/// A london break of the Asian range is measured on the chart (the range,
/// the break, the retest close). Any other strategy's entry stays "waiting"
/// and the brief says to check it on the trader's own chart.
class FakeBrief implements BriefSource {
  const FakeBrief({
    required this.market,
    required this.news,
    this.latency = const Duration(milliseconds: 600),
  });

  final MarketData market;
  final NewsCalendar news;

  /// Simulated model time, so the loading state is real.
  final Duration latency;

  /// High-impact news this far ahead goes in the risk note.
  static const _newsHorizon = Duration(hours: 12);

  @override
  Future<PairBrief> brief(BriefRequest r) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    TimeZones.ensureInitialized();
    final now = r.now.toUtc();
    final instrument = instrumentBySymbol(r.symbol);
    final name = displaySymbol(r.symbol);
    final c = r.coach;
    final zone = userZoneFromProfile(r.profile);
    final reading = StrategyReading.of(r.profile.strategy?.parsed);
    final status = MarketStatus.of(instrument, now);
    final quote = await market.quote(r.symbol, now: now);
    final decimals = quote?.decimals ?? 2;
    String at(DateTime t) => clockDayTime(zone, t, now: now);

    // --- news ---------------------------------------------------------------
    final currencies = newsCurrencies(instrument);
    final events = currencies.isEmpty
        ? const <NewsEvent>[]
        : await news.highImpact(
            currencies: currencies,
            from: now.subtract(const Duration(minutes: kNewsBufferMinutes)),
            to: now.add(const Duration(hours: 24)),
          );
    final inWindow = events.where((e) => e.covers(now)).firstOrNull;
    final upcoming = events.where((e) => e.at.isAfter(now)).firstOrNull;
    final soon = upcoming != null && upcoming.at.difference(now) <= _newsHorizon ? upcoming : null;

    // --- the london break, measured -----------------------------------------
    final measuresRange =
        r.profile.strategy?.conditions.any((x) => x.kind == ConditionKind.rangeBreak) ??
        reading.kind == StrategyKind.londonBreak;
    final lb = measuresRange && instrument != null && status.isOpen
        ? await _londonBreak(r.symbol, reading.timeframe, now)
        : null;

    // --- rules --------------------------------------------------------------
    final max = c.maxTradesPerDay;
    final limit = c.dailyLossLimitPct;
    final maxHit = max != null && c.tradesToday >= max;
    final limitHit = limit != null && c.lossTodayPct > 0 && c.lossTodayPct >= limit;
    final dayDone = maxHit || limitHit;

    // --- 03 · conditions: the account's own, measured --------------------
    final strategyConditions = r.profile.strategy?.conditions ?? defaultConditions(null);
    final measured = measureConditions(
      strategyConditions,
      ConditionFacts(
        now: now,
        marketOpen: status.isOpen,
        traderSessions: r.profile.sessions,
        tradesToday: c.tradesToday,
        lossTodayPct: c.lossTodayPct,
        maxTradesPerDay: max,
        dailyLossLimitPct: limit,
        rangeBroke: lb?.breakAt != null,
        closedBack: lb?.retestAt != null,
        rangeOver: lb?.londonOver ?? false,
        newsKnown: currencies.isNotEmpty,
        newsInWindow: inWindow != null,
        timeframeLabel: reading.timeframe.label,
      ),
    );
    final tf = reading.timeframe;
    final conditions = measured.conditions;
    final waitingSession = measured.waitingSession;
    final sessionOpensAt = measured.sessionOpensAt;

    // --- 01 · market context ------------------------------------------------
    final context = <String>[];
    if (status case MarketClosed(:final opensAt)) {
      context.add(
        opensAt == null
            ? '$name is closed. the brief picks up when it opens.'
            : '$name is closed until ${at(opensAt)}. the brief picks up when it opens.',
      );
    } else {
      if (instrument?.assetClass == AssetClass.synthetic) {
        context.add("$name runs around the clock on deriv's own generator, so news doesn't move it.");
      }
      final range = lb?.range;
      final days = instrument == null
          ? const <Candle>[]
          : await market.candles(r.symbol, Timeframe.d1, now: now, count: 6);
      if (range != null) {
        final size = distanceLabel(instrument, range.size, decimals: decimals);
        context.add(
          lb!.breakAt == null
              ? '$name has held a $size range since the asian open.'
              : '$name left its $size asian range at ${at(lb.breakAt!)}.',
        );
      } else if (days.isNotEmpty) {
        final today = days.last;
        context.add(
          '$name has moved in a ${distanceLabel(instrument, today.high - today.low, decimals: decimals)} range today.',
        );
      }
      if (days.length >= 2) {
        final today = days.last.high - days.last.low;
        final before = days.sublist(0, days.length - 1);
        final average = before.fold(0.0, (s, d) => s + d.high - d.low) / before.length;
        final ratio = average == 0 ? 1.0 : today / average;
        final word = ratio < 0.6
            ? 'well below'
            : ratio < 0.85
            ? 'below'
            : ratio <= 1.15
            ? 'close to'
            : ratio <= 1.5
            ? 'above'
            : 'well above';
        context.add("today's range is $word its ${before.length}-day average.");
      }
      if (instrument == null) {
        context.add('doji has no prices for $name yet, so this brief checks your rules only.');
      }
    }

    // --- 02 · what your strategy says ---------------------------------------
    final risk = c.riskPerTradePct;
    final blocker = inWindow != null
        ? 'the news window'
        : conditions.any((x) => x.text.endsWith('session is open') && !x.met)
        ? 'the session'
        : null;
    final String strategy;
    switch (reading.kind) {
      case StrategyKind.none:
        strategy =
            "you haven't described a strategy yet, so this brief checks your rules only. describe it and every "
            'brief is measured against it.';
      case StrategyKind.other:
        strategy =
            '${_lead(reading)} doji can\'t read this setup from the chart yet, so your entry stays waiting: '
            'check it on your own chart.';
      case StrategyKind.londonBreak:
        final String state;
        if (dayDone) {
          state = 'your plan is done for today, whatever the chart does.';
        } else if (!status.isOpen) {
          state = 'the market is closed. nothing to do until it opens.';
        } else if (lb!.londonOver) {
          state = 'the london session is over. this setup is done for today.';
        } else if (lb.range == null || lb.forming) {
          state = "the asian range is still forming. nothing to do yet — that's discipline.";
        } else if (lb.breakAt == null) {
          state = "no break yet. nothing to do yet — that's discipline.";
        } else if (reading.retest && lb.retestAt == null) {
          state =
              "the range broke at ${at(lb.breakAt!)}, no retest close yet. nothing to do yet — that's discipline.";
        } else if (blocker != null) {
          state = "your setup has formed, but $blocker says not now. that's the plan working.";
        } else {
          state = risk == null
              ? 'every condition on your list is in place. whether you take it is your call.'
              : 'every condition on your list is in place. whether you take it, at ${_n(risk)}% risk, is your call.';
        }
        strategy = '${_lead(reading)} $state';
    }

    // --- 04 · risk note -----------------------------------------------------
    final riskStays = risk == null ? 'keep your size where your plan has it.' : 'risk stays at ${_n(risk)}%.';
    final String riskNote;
    if (limitHit) {
      riskNote = "today's loss is at your ${_n(limit)}% limit. your rule says the day is done.";
    } else if (maxHit) {
      riskNote = "you've taken ${c.tradesToday} of $max trades today. your rule says that's the day.";
    } else if (inWindow != null) {
      riskNote =
          'high-impact news window until ${at(inWindow.windowEnd)}. your rules say no entries until it closes. '
          'after that, $riskStays';
    } else if (soon != null) {
      riskNote =
          'high-impact news at ${at(soon.at)}. your rules say no entries $kNewsBufferMinutes min either side. '
          'if a setup forms after, $riskStays';
    } else if (c.lossStreak >= 2) {
      riskNote = risk == null
          ? '${c.lossStreak} losses in a row today. if a setup forms, it gets the same size as any other.'
          : '${c.lossStreak} losses in a row today. if a setup forms, it gets the same ${_n(risk)}% as any other.';
    } else if (instrument?.assetClass == AssetClass.synthetic) {
      riskNote = "synthetic indices don't follow the news calendar. $riskStays";
    } else {
      riskNote = 'no high-impact news in the next 12 hours on the sample calendar. $riskStays';
    }

    // --- 05 · check again ---------------------------------------------------
    final CheckAgain? checkAgain;
    if (dayDone) {
      checkAgain = null;
    } else if (status case MarketClosed(:final opensAt)) {
      checkAgain = opensAt == null ? null : CheckAgain(opensAt, 'when the market opens');
    } else if (inWindow != null) {
      checkAgain = CheckAgain(inWindow.windowEnd, 'after the news window closes');
    } else if (waitingSession != null && sessionOpensAt != null) {
      checkAgain = CheckAgain(sessionOpensAt, 'when the ${waitingSession.label.toLowerCase()} session opens');
    } else if (lb?.londonOver ?? false) {
      final open = TradingSession.london.nextOpenAfter(now);
      checkAgain = open == null ? null : CheckAgain(open, 'when the london session opens');
    } else if (soon != null && soon.at.difference(now) <= const Duration(hours: 1)) {
      checkAgain = CheckAgain(soon.windowEnd, 'after the news window closes');
    } else {
      checkAgain = CheckAgain(tf.bucketOf(now).add(tf.duration), 'at the next ${tf.label} close');
    }

    final range = lb?.range;
    return PairBrief(
      symbol: r.symbol,
      updatedAt: now,
      context: context.join(' '),
      strategyName: reading.setup,
      strategy: strategy,
      conditions: conditions,
      riskNote: riskNote,
      checkAgain: checkAgain,
      followUps: [
        if (conditions.any((x) => x.status == ConditionStatus.waiting)) 'why is this waiting?',
        'explain the risk note',
        if (reading.retest)
          'what counts as a retest?'
        else if (reading.entry != null)
          'what does my entry need?',
      ],
      levels: range == null
          ? null
          : StrategyLevels(
              range: range,
              highLabel: 'ASIA HI',
              lowLabel: 'ASIA LO',
              spoken: 'your asian range levels',
            ),
      nextNews: inWindow ?? upcoming,
      dayDone: dayDone,
    );
  }

  /// "your setup: london breakout of the asian range. your entry: retest of
  /// the broken level, candle closes beyond, on M15."
  static String _lead(StrategyReading s) {
    final tf = s.timeframe.label;
    final setup = s.setup == null ? '' : 'your setup: ${s.setup}. ';
    final entry = s.entry == null ? 'your timeframe: $tf.' : 'your entry: ${s.entry}, on $tf.';
    return '$setup$entry';
  }

  /// The Asian range (Tokyo open to London open), and in London the first
  /// break of it and the first [tf] close back beyond the broken level.
  Future<_LondonBreak> _londonBreak(String symbol, Timeframe tf, DateTime now) async {
    var tokyoOpen = TradingSession.tokyo.openInstant(now)!;
    if (tokyoOpen.isAfter(now)) {
      tokyoOpen = TradingSession.tokyo.openInstant(now.subtract(const Duration(days: 1)))!;
    }
    final londonOpen = TradingSession.london.openInstant(tokyoOpen)!;
    final londonClose = TradingSession.london.closeInstant(tokyoOpen)!;
    final forming = now.isBefore(londonOpen);
    final asian = await market.candlesBetween(
      symbol,
      Timeframe.m15,
      from: tokyoOpen,
      to: forming ? now : londonOpen,
    );
    final range = PriceRange.of(asian);
    final over = !now.isBefore(londonClose);
    if (range == null || forming) return _LondonBreak(range: range, forming: forming, londonOver: over);
    final london = await market.candlesBetween(symbol, tf, from: londonOpen, to: over ? londonClose : now);
    DateTime? breakAt, retestAt;
    bool? up;
    for (final k in london) {
      if (breakAt == null) {
        if (k.high > range.high || k.low < range.low) {
          breakAt = k.at;
          up = k.high > range.high && (k.low >= range.low || k.close >= range.high);
        }
        continue;
      }
      // Only closed bars count as a close back beyond the level.
      if (k.at.add(tf.duration).isAfter(now)) break;
      final retest = up!
          ? k.low <= range.high && k.close > range.high
          : k.high >= range.low && k.close < range.low;
      if (retest) {
        retestAt = k.at.add(tf.duration);
        break;
      }
    }
    return _LondonBreak(range: range, forming: false, londonOver: over, breakAt: breakAt, retestAt: retestAt);
  }

  /// 1.5 → "1.5", 2.0 → "2".
  static String _n(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }
}

class _LondonBreak {
  const _LondonBreak({
    required this.range,
    required this.forming,
    required this.londonOver,
    this.breakAt,
    this.retestAt,
  });

  final PriceRange? range;

  /// Before the London open: the range is still being made.
  final bool forming;

  /// After the London close: the setup is done for today.
  final bool londonOver;

  /// Open time of the bar that first left the range.
  final DateTime? breakAt;

  /// Close time of the first bar that closed back beyond the broken level.
  final DateTime? retestAt;
}

/// The brief 1b shows. Tests override it with a zero-latency [FakeBrief].
final briefSourceProvider = Provider<BriefSource>(
  (ref) => FakeBrief(market: ref.watch(marketDataProvider), news: ref.watch(newsCalendarProvider)),
);

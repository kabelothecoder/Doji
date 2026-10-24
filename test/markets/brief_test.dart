// The doji brief (handoff 1b) worked out by FakeBrief: conditions measured on
// hand-made candles so every branch is pinned (forming range, break, retest,
// news window, day done, market closed), and the brief chat's answers.
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/markets/data/fake_brief.dart';
import 'package:doji_app/features/markets/data/fake_brief_chat.dart';
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:doji_app/features/markets/data/sample_news_calendar.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/markets/domain/pair_brief.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journal/journal_fixtures.dart';

/// Wednesday 15 July 2026 (summer): Tokyo opens 00:00 UTC, London 07:00 UTC,
/// the sample USD release is 08:30 New York = 12:30 UTC. Johannesburg is UTC+2.
DateTime utc(int h, [int m = 0]) => DateTime.utc(2026, 7, 15, h, m);

const _strategy = StrategyProfile(
  parsed: ParsedStrategy(
    setup: 'london breakout of the asian range',
    timeframe: 'M15',
    entry: 'retest of the broken level, candle closes beyond',
  ),
);

const _profile = ProfileDoji(
  name: 'sam',
  sessions: ['london'],
  timeZone: 'Africa/Johannesburg',
  utcOffsetMinutes: 120,
  strategy: _strategy,
  rules: TradingRules(riskPerTrade: 3, maxTradesPerDay: 3, dailyLossLimit: 2),
);

/// M15 bars: an Asian range of 1.08000–1.08300, a break up at 08:00 UTC and
/// a close back above the broken high at 09:00 (closes 09:15).
List<Candle> _bars() {
  final out = <Candle>[];
  for (var t = utc(0); t.isBefore(utc(13)); t = t.add(const Duration(minutes: 15))) {
    final i = out.length;
    final Candle c;
    if (t.isBefore(utc(7))) {
      final hi = i == 5 ? 1.0830 : 1.0822, lo = i == 12 ? 1.0800 : 1.0808;
      c = Candle(at: t, open: 1.0812, high: hi, low: lo, close: 1.0815);
    } else if (t.isBefore(utc(8))) {
      c = Candle(at: t, open: 1.0815, high: 1.0826, low: 1.0810, close: 1.0820);
    } else if (t == utc(8)) {
      c = Candle(at: t, open: 1.0820, high: 1.0845, low: 1.0818, close: 1.0842);
    } else if (t == utc(9)) {
      c = Candle(at: t, open: 1.0840, high: 1.0841, low: 1.0828, close: 1.0836);
    } else {
      c = Candle(at: t, open: 1.0838, high: 1.0846, low: 1.0834, close: 1.0840);
    }
    out.add(c);
  }
  return out;
}

class _StubMarket implements MarketData {
  _StubMarket({this.open = true});

  final bool open;
  final bars = _bars();

  @override
  bool get isSample => true;

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) async =>
      Quote(symbol: symbol, price: 1.0840, dayOpen: 1.0812, at: now, decimals: 5, marketOpen: open);

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) async {
    if (tf == Timeframe.d1) {
      return [
        for (var d = 5; d >= 0; d--)
          Candle(at: utc(0).subtract(Duration(days: d)), open: 1.08, high: 1.0870, low: 1.0800, close: 1.084),
      ];
    }
    return bars.where((b) => !b.at.isAfter(now)).toList();
  }

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async => bars.where((b) => !b.at.isBefore(from) && b.at.isBefore(to)).toList();
}

Future<PairBrief> _brief(
  DateTime now, {
  ProfileDoji profile = _profile,
  List<Trade> trades = const [],
  String symbol = 'EURUSD',
  MarketData? market,
}) => FakeBrief(
  market: market ?? _StubMarket(),
  news: const SampleNewsCalendar(),
  latency: Duration.zero,
).brief(BriefRequest(symbol: symbol, profile: profile, trades: trades, now: now));

Map<String, ConditionStatus> _statuses(PairBrief b) => {for (final c in b.conditions) c.text: c.status};

void main() {
  group('london break, measured', () {
    test('before London: the range is still forming, check again at the open', () async {
      final b = await _brief(utc(6));
      expect(_statuses(b), {
        'London session is open': ConditionStatus.waiting,
        'Trades today under your max of 3': ConditionStatus.met,
        "Today's loss under your 2% limit": ConditionStatus.met,
        'Price breaks the Asian range high or low': ConditionStatus.waiting,
        'M15 candle closes back beyond the broken level': ConditionStatus.waiting,
        'No high-impact news within 15 min': ConditionStatus.met,
      });
      expect(b.strategy, contains('the asian range is still forming'));
      expect(b.checkAgain!.at, utc(7));
      expect(b.checkAgain!.why, 'when the london session opens');
      expect(b.levels!.highLabel, 'ASIA HI');
    });

    test('broken, no retest close yet: waiting on the retest, nothing to do', () async {
      final b = await _brief(utc(8, 30));
      final s = _statuses(b);
      expect(s['Price breaks the Asian range high or low'], ConditionStatus.met);
      expect(s['M15 candle closes back beyond the broken level'], ConditionStatus.waiting);
      expect(b.context, startsWith('EUR/USD left its 30-pip asian range at 10:00.'));
      expect(
        b.strategy,
        contains("the range broke at 10:00, no retest close yet. nothing to do yet — that's discipline."),
      );
      expect(b.levels!.range.high, 1.0830);
      expect(b.levels!.range.low, 1.0800);
      expect(b.followUps, ['why is this waiting?', 'explain the risk note', 'what counts as a retest?']);
    });

    test('everything in place: the brief says so and leaves the decision with the trader', () async {
      final b = await _brief(utc(12));
      expect(b.conditions.every((c) => c.met), isTrue, reason: '${_statuses(b)}');
      expect(
        b.strategy,
        endsWith('every condition on your list is in place. whether you take it, at 3% risk, is your call.'),
      );
      // The 12:30 UTC release is within the hour: check again after its window.
      expect(
        b.riskNote,
        'high-impact news at 14:30. your rules say no entries 15 min either side. '
        'if a setup forms after, risk stays at 3%.',
      );
      expect(b.checkAgain!.at, utc(12, 45));
      expect(b.checkAgain!.why, 'after the news window closes');
      expect(b.nextNews!.at, utc(12, 30));
    });

    test('inside the news window: not met, and the setup waits for it', () async {
      final b = await _brief(utc(12, 20));
      expect(_statuses(b)['No high-impact news within 15 min'], ConditionStatus.notMet);
      expect(
        b.strategy,
        contains("your setup has formed, but the news window says not now. that's the plan working."),
      );
      expect(b.riskNote, startsWith('high-impact news window until 14:45.'));
      expect(b.checkAgain!.at, utc(12, 45));
    });

    test('after the London close: this setup is done for today', () async {
      final b = await _brief(utc(17));
      expect(_statuses(b)['London session is open'], ConditionStatus.notMet);
      expect(b.strategy, contains('the london session is over. this setup is done for today.'));
      expect(b.checkAgain!.why, 'when the london session opens');
      expect(b.checkAgain!.at, DateTime.utc(2026, 7, 16, 7));
    });
  });

  test('max trades reached: the day is done, no check again', () async {
    final now = utc(12);
    // Winners, so only the trade count (not the loss limit or a streak) ends the day.
    final trades = [
      for (var i = 0; i < 3; i++) sampleTrade(id: 't$i', pnl: 20, now: now, minutesAgo: 60 * (i + 1)),
    ];
    final b = await _brief(now, trades: trades);
    expect(b.dayDone, isTrue);
    expect(_statuses(b)['Trades today under your max of 3'], ConditionStatus.notMet);
    expect(b.riskNote, "you've taken 3 of 3 trades today. your rule says that's the day.");
    expect(b.strategy, contains('your plan is done for today'));
    expect(b.checkAgain, isNull);
  });

  test('market closed on Saturday: says when it opens', () async {
    final saturday = DateTime.utc(2026, 7, 18, 12);
    final b = await _brief(saturday, market: _StubMarket(open: false));
    expect(b.conditions.first.text, 'The market is open');
    expect(b.conditions.first.status, ConditionStatus.notMet);
    // The FX week opens Sunday 17:00 New York = 21:00 UTC = 23:00 Johannesburg.
    expect(b.context, 'EUR/USD is closed until tomorrow 23:00. the brief picks up when it opens.');
    expect(b.checkAgain!.why, 'when the market opens');
    expect(b.checkAgain!.at, DateTime.utc(2026, 7, 19, 21));
  });

  test('no strategy described: rules only, and it says so', () async {
    final b = await _brief(utc(12), profile: _profile.copyWith(strategy: null));
    expect(b.strategyName, isNull);
    expect(b.strategy, startsWith("you haven't described a strategy yet"));
    expect(b.levels, isNull);
    expect(b.conditions.map((c) => c.text), [
      'London session is open',
      'Trades today under your max of 3',
      "Today's loss under your 2% limit",
      'No high-impact news within 15 min',
    ]);
    expect(b.followUps, isNot(contains('what counts as a retest?')));
  });

  test('a strategy doji cannot read from the chart: the entry waits, check your own chart', () async {
    final b = await _brief(
      utc(12),
      profile: _profile.copyWith(
        strategy: const StrategyProfile(
          parsed: ParsedStrategy(setup: 'order block mitigation', timeframe: 'H1', entry: 'engulfing close'),
        ),
      ),
    );
    expect(_statuses(b)['Your entry: engulfing close (H1)'], ConditionStatus.waiting);
    expect(b.strategy, contains("doji can't read this setup from the chart yet"));
    expect(b.checkAgain!.why, anyOf('at the next H1 close', 'after the news window closes'));
    expect(b.followUps, contains('what does my entry need?'));
  });

  test('synthetic indices: no news condition, and the context says why', () async {
    final b =
        await const FakeBrief(
          market: FakeMarketData(latency: Duration.zero),
          news: SampleNewsCalendar(),
          latency: Duration.zero,
        ).brief(
          BriefRequest(
            symbol: 'R_75',
            profile: _profile.copyWith(strategy: null),
            trades: const [],
            now: utc(12),
          ),
        );
    expect(b.conditions.map((c) => c.text), isNot(contains('No high-impact news within 15 min')));
    expect(b.context, startsWith("Volatility 75 runs around the clock on deriv's own generator"));
    expect(b.riskNote, "synthetic indices don't follow the news calendar. risk stays at 3%.");
    expect(b.nextNews, isNull);
  });

  group('brief chat', () {
    Future<(PairBrief, BriefRequest)> setup(DateTime now) async {
      final r = BriefRequest(symbol: 'EURUSD', profile: _profile, trades: const [], now: now);
      return (await _brief(now), r);
    }

    test('why is this waiting: names what is still waiting', () async {
      final (b, r) = await setup(utc(8, 30));
      expect(
        FakeBriefChat.replyFor(b, r, 'why is this waiting?'),
        'one condition is still waiting: m15 candle closes back beyond the broken level. doji marks a condition '
        'met only when your rule is met, not when it looks close.',
      );
    });

    test('what counts as a retest: the trader\'s own entry rule', () async {
      final (b, r) = await setup(utc(8, 30));
      expect(
        FakeBriefChat.replyFor(b, r, 'what counts as a retest?'),
        contains('retest of the broken level'),
      );
    });

    test('the risk note: the news rule and the same size', () async {
      final (b, r) = await setup(utc(12));
      expect(
        FakeBriefChat.replyFor(b, r, 'explain the risk note'),
        'big releases can move price fast and widen spreads, so your rule keeps you out 15 min either side of '
        '14:30. outside that window, risk stays at 3% a trade, the same as any trade.',
      );
    });

    test('asked for a call, it declines; crisis words get the helpline first', () async {
      final (b, r) = await setup(utc(12));
      expect(FakeBriefChat.replyFor(b, r, 'should i go long here?'), contains("i don't call the market"));
      expect(FakeBriefChat.replyFor(b, r, 'i want to die'), contains('SADAG'));
    });
  });

  test('copy rules: nothing the brief or its chat says is a call, signal or promise', () async {
    final lines = <String>[];
    for (final now in [utc(6), utc(8, 30), utc(12), utc(12, 20), utc(17), DateTime.utc(2026, 7, 18, 12)]) {
      for (final profile in [_profile, _profile.copyWith(strategy: null)]) {
        final b = await _brief(now, profile: profile);
        final r = BriefRequest(symbol: 'EURUSD', profile: profile, trades: const [], now: now);
        lines
          ..add(b.context)
          ..add(b.strategy)
          ..add(b.riskNote)
          ..addAll(b.conditions.map((c) => c.text))
          ..addAll(b.followUps)
          ..add(b.checkAgain?.why ?? '');
        for (final q in [...b.followUps, 'what now?']) {
          lines.add(FakeBriefChat.replyFor(b, r, q));
        }
      }
    }
    final text = ' ${lines.join(' ').toLowerCase()} ';
    for (final banned in [
      ' buy ',
      ' sell ',
      'signal',
      'guarantee',
      'profit',
      'win rate',
      'go long',
      'go short',
    ]) {
      expect(text, isNot(contains(banned)), reason: banned);
    }
  });
}

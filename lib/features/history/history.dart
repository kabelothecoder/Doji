import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../markets/data/routed_market_data.dart';
import '../markets/domain/candle.dart';
import '../markets/domain/market_data.dart';
import '../onboarding/data/onboarding_repository.dart';

/// Cached candles of one instrument and timeframe, with the dates they cover.
/// [from]–[to] is what was asked for and fetched; bars only exist while the
/// market was open, so weekends inside it are not gaps.
class HistoryRange {
  const HistoryRange({
    required this.symbol,
    required this.timeframe,
    required this.from,
    required this.to,
    required this.candles,
  });

  final String symbol;
  final Timeframe timeframe;
  final DateTime from;
  final DateTime to;

  /// Oldest first, no duplicates.
  final List<Candle> candles;

  bool get isEmpty => candles.isEmpty;

  /// The bars from [start] (inclusive) to [end] (exclusive).
  List<Candle> between(DateTime start, DateTime end) => [
    for (final c in candles)
      if (!c.at.isBefore(start) && c.at.isBefore(end)) c,
  ];

  Map<String, dynamic> toJson() => {
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
    'bars': [
      for (final c in candles) [c.at.millisecondsSinceEpoch, c.open, c.high, c.low, c.close],
    ],
  };

  static HistoryRange? fromJson(String symbol, Timeframe tf, Object? json) {
    if (json is! Map) return null;
    final from = DateTime.tryParse('${json['from']}'), to = DateTime.tryParse('${json['to']}');
    final bars = json['bars'];
    if (from == null || to == null || bars is! List) return null;
    final candles = <Candle>[];
    for (final b in bars) {
      // A bar that fails to parse is skipped; the rest of the history stays.
      if (b is! List || b.length != 5 || b.any((v) => v is! num)) continue;
      candles.add(
        Candle(
          at: DateTime.fromMillisecondsSinceEpoch((b[0] as num).toInt(), isUtc: true),
          open: (b[1] as num).toDouble(),
          high: (b[2] as num).toDouble(),
          low: (b[3] as num).toDouble(),
          close: (b[4] as num).toDouble(),
        ),
      );
    }
    return HistoryRange(symbol: symbol, timeframe: tf, from: from.toUtc(), to: to.toUtc(), candles: candles);
  }
}

/// Where cached history lives. On this device only: history can always be
/// fetched again, so it is never synced.
abstract interface class HistoryRepository {
  HistoryRange? load(String symbol, Timeframe tf);
  Future<void> save(HistoryRange range);
  Future<void> clear();
}

class PrefsHistoryRepository implements HistoryRepository {
  PrefsHistoryRepository(this._prefs);

  final SharedPreferences _prefs;

  static const prefix = 'doji.history.v1.';
  static String keyOf(String symbol, Timeframe tf) => '$prefix${symbol.toUpperCase()}.${tf.label}';

  @override
  HistoryRange? load(String symbol, Timeframe tf) {
    final raw = _prefs.getString(keyOf(symbol, tf));
    if (raw == null) return null;
    try {
      return HistoryRange.fromJson(symbol.toUpperCase(), tf, jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(HistoryRange range) =>
      _prefs.setString(keyOf(range.symbol, range.timeframe), jsonEncode(range.toJson()));

  @override
  Future<void> clear() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _prefs.remove(k);
    }
  }
}

/// Fetches history from slice 02's feeds (Deriv `ticks_history`, MT5 through
/// the `mt5` function's paged bars, sample prices otherwise) and keeps it on
/// the device. Only the missing edges are fetched.
class HistoryService {
  HistoryService(this._market, this._repo);

  final MarketData _market;
  final HistoryRepository _repo;

  /// Most bars kept per instrument and timeframe; the oldest go first.
  static const maxBars = 20000;

  /// Bars asked for in one request (Deriv answers up to 5,000, the `mt5`
  /// function up to 3,000).
  static const chunkBars = 2500;

  HistoryRange? cached(String symbol, Timeframe tf) => _repo.load(symbol, tf);

  /// History of [symbol] on [tf] covering [from]–[to], fetching what the cache
  /// lacks. A feed that does not answer throws [FeedUnavailable]; what was
  /// cached before stays.
  Future<HistoryRange> ensure(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async {
    final sym = symbol.toUpperCase();
    from = from.toUtc();
    to = to.toUtc();
    final old = _repo.load(sym, tf);
    final gaps = <(DateTime, DateTime)>[
      if (old == null) (from, to),
      if (old != null && from.isBefore(old.from)) (from, old.from),
      if (old != null && to.isAfter(old.to)) (old.to, to),
    ];
    if (gaps.isEmpty) return old!;
    final byTime = {for (final c in old?.candles ?? const <Candle>[]) c.at.millisecondsSinceEpoch: c};
    final step = tf.duration * chunkBars;
    for (final (start, end) in gaps) {
      for (var a = start; a.isBefore(end); a = a.add(step)) {
        final b = a.add(step).isAfter(end) ? end : a.add(step);
        for (final c in await _market.candlesBetween(sym, tf, from: a, to: b)) {
          if (c.at.isBefore(start) || c.at.isAfter(end)) continue;
          byTime[c.at.millisecondsSinceEpoch] = c;
        }
      }
    }
    var candles = byTime.values.toList()..sort((x, y) => x.at.compareTo(y.at));
    var coveredFrom = old == null || from.isBefore(old.from) ? from : old.from;
    final coveredTo = old == null || to.isAfter(old.to) ? to : old.to;
    if (candles.length > maxBars) {
      candles = candles.sublist(candles.length - maxBars);
      coveredFrom = candles.first.at;
    }
    final range = HistoryRange(
      symbol: sym,
      timeframe: tf,
      from: coveredFrom,
      to: coveredTo,
      candles: candles,
    );
    await _repo.save(range);
    return range;
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => PrefsHistoryRepository(ref.watch(sharedPreferencesProvider)),
);

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(ref.watch(marketDataProvider), ref.watch(historyRepositoryProvider)),
);

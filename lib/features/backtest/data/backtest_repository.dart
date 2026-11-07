import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../markets/domain/candle.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/backtest.dart';

/// How a session's trades were made.
enum BacktestKind {
  /// The automatic backtest of the measurable conditions.
  auto,

  /// The trader's own replay (manual backtest).
  replay,

  /// A gym replay practice.
  gym;

  static BacktestKind fromName(String? n) => values.where((v) => v.name == n).firstOrNull ?? auto;
}

/// One backtest run or replay, per account and strategy version. Kept for
/// the trader and for the AI analyst (slice 06).
class BacktestSession {
  const BacktestSession({
    required this.id,
    required this.accountId,
    required this.strategyVersion,
    required this.kind,
    required this.symbols,
    required this.timeframe,
    required this.from,
    required this.to,
    required this.createdAt,
    this.trades = const [],
    this.label,
  });

  final String id;
  final String accountId;

  /// The account's strategy number when it ran (a draft keeps its base's).
  final int strategyVersion;
  final BacktestKind kind;
  final List<String> symbols;
  final Timeframe timeframe;
  final DateTime from;
  final DateTime to;
  final DateTime createdAt;
  final List<BacktestTrade> trades;

  /// "current strategy", "draft: target 2R → 3R", a replay's day.
  final String? label;

  BacktestStats get stats => BacktestStats.of(trades);

  BacktestSession withTrades(List<BacktestTrade> trades) => BacktestSession(
    id: id,
    accountId: accountId,
    strategyVersion: strategyVersion,
    kind: kind,
    symbols: symbols,
    timeframe: timeframe,
    from: from,
    to: to,
    createdAt: createdAt,
    trades: trades,
    label: label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'strategyVersion': strategyVersion,
    'kind': kind.name,
    'symbols': symbols,
    'timeframe': timeframe.label,
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'trades': [for (final t in trades) t.toJson()],
    'label': label,
  };

  static BacktestSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final from = DateTime.tryParse('${j['from']}'), to = DateTime.tryParse('${j['to']}');
    final created = DateTime.tryParse('${j['createdAt']}');
    final tf = Timeframe.parse('${j['timeframe']}');
    if (j['id'] is! String ||
        j['accountId'] is! String ||
        from == null ||
        to == null ||
        created == null ||
        tf == null) {
      return null;
    }
    return BacktestSession(
      id: j['id'] as String,
      accountId: j['accountId'] as String,
      strategyVersion: (j['strategyVersion'] as num?)?.toInt() ?? 1,
      kind: BacktestKind.fromName(j['kind'] as String?),
      symbols: [for (final s in (j['symbols'] as List? ?? const [])) '$s'],
      timeframe: tf,
      from: from.toUtc(),
      to: to.toUtc(),
      createdAt: created.toUtc(),
      trades: [for (final t in (j['trades'] as List? ?? const [])) ?BacktestTrade.fromJson(t)],
      label: j['label'] as String?,
    );
  }

  /// What the AI analyst reads: the run's shape and results, not the bars.
  Map<String, dynamic> toAnalystJson() {
    final s = stats;
    return {
      'kind': kind.name,
      'accountId': accountId,
      'strategyVersion': strategyVersion,
      'symbols': symbols,
      'timeframe': timeframe.label,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'label': label,
      'setups': s.setups,
      'totalR': s.totalR,
      'maxLosingStreak': s.maxLosingStreak,
      'maxDrawdownR': s.maxDrawdownR,
    };
  }
}

/// Where backtest sessions live.
///
/// TODO(next-slice): Supabase sync, as planned for the journal
/// (`journal_repository.dart`): a `backtest_sessions` table keyed by `id`,
/// owned by `auth.uid()`. Local stays the source until then.
abstract interface class BacktestRepository {
  List<BacktestSession> load();
  Future<void> save(List<BacktestSession> sessions);
  Future<void> clear();
}

class PrefsBacktestRepository implements BacktestRepository {
  PrefsBacktestRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.backtest.v1';

  @override
  List<BacktestSession> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['sessions'] : null;
      if (list is! List) return const [];
      // A record that fails to parse is skipped; the rest stays.
      return [for (final s in list) ?BacktestSession.fromJson(s)];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<BacktestSession> sessions) => _prefs.setString(
    key,
    jsonEncode({
      'version': 1,
      'sessions': [for (final s in sessions) s.toJson()],
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}

final backtestRepositoryProvider = Provider<BacktestRepository>(
  (ref) => PrefsBacktestRepository(ref.watch(sharedPreferencesProvider)),
);

/// Every saved session, newest last.
class BacktestSessionsController extends Notifier<List<BacktestSession>> {
  /// Oldest are dropped past this many.
  static const keep = 200;

  @override
  List<BacktestSession> build() => ref.watch(backtestRepositoryProvider).load();

  Future<void> upsert(BacktestSession s) async {
    final next = [...state.where((x) => x.id != s.id), s];
    state = next.length > keep ? next.sublist(next.length - keep) : next;
    await ref.read(backtestRepositoryProvider).save(state);
  }
}

final backtestSessionsProvider = NotifierProvider<BacktestSessionsController, List<BacktestSession>>(
  BacktestSessionsController.new,
);

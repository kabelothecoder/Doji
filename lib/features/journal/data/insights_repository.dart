import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accounts/presentation/accounts_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../domain/insights.dart';
import '../presentation/journal_controller.dart';
import '../presentation/journal_screen.dart' show kInsightsFromTrades;

/// What the trader did with insights and imported trades: watched and hidden insight ids, rules
/// added from an insight, and imported trades put off with "later".
class InsightPrefs {
  const InsightPrefs({
    this.watching = const {},
    this.hidden = const {},
    this.ruled = const {},
    this.later = const {},
  });

  final Set<String> watching;
  final Set<String> hidden;
  final Set<String> ruled;

  /// Imported trade ids whose banner was dismissed.
  final Set<String> later;

  InsightPrefs copyWith({
    Set<String>? watching,
    Set<String>? hidden,
    Set<String>? ruled,
    Set<String>? later,
  }) => InsightPrefs(
    watching: watching ?? this.watching,
    hidden: hidden ?? this.hidden,
    ruled: ruled ?? this.ruled,
    later: later ?? this.later,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'watching': watching.toList(),
    'hidden': hidden.toList(),
    'ruled': ruled.toList(),
    'later': later.toList(),
  };

  static InsightPrefs fromJson(Object? json) {
    if (json is! Map) return const InsightPrefs();
    Set<String> set(String k) => {
      if (json[k] is List)
        for (final v in json[k] as List)
          if (v is String) v,
    };
    return InsightPrefs(
      watching: set('watching'),
      hidden: set('hidden'),
      ruled: set('ruled'),
      later: set('later'),
    );
  }
}

/// TODO(backend): sync with the journal (insight feedback also tunes the analyst).
class InsightsRepository {
  InsightsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.insights.v1';

  InsightPrefs load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const InsightPrefs();
    try {
      return InsightPrefs.fromJson(jsonDecode(raw));
    } on FormatException {
      return const InsightPrefs();
    }
  }

  Future<void> save(InsightPrefs p) => _prefs.setString(key, jsonEncode(p.toJson()));

  Future<void> clear() => _prefs.remove(key);
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(sharedPreferencesProvider)),
);

class InsightPrefsController extends Notifier<InsightPrefs> {
  @override
  InsightPrefs build() => ref.watch(insightsRepositoryProvider).load();

  void _set(InsightPrefs p) {
    state = p;
    ref.read(insightsRepositoryProvider).save(p).ignore();
  }

  Set<String> _flip(Set<String> s, String id) => s.contains(id) ? ({...s}..remove(id)) : {...s, id};

  void toggleWatch(String id) => _set(state.copyWith(watching: _flip(state.watching, id)));

  /// "not useful" and its undo.
  void toggleHidden(String id) => _set(state.copyWith(hidden: _flip(state.hidden, id)));

  void later(String tradeId) => _set(state.copyWith(later: {...state.later, tradeId}));

  /// Adds [insight]'s rule to the active account's "when i don't trade" lines, once.
  Future<void> addRule(Insight insight) async {
    if (state.ruled.contains(insight.id)) return;
    final accounts = ref.read(accountsControllerProvider.notifier);
    final account = ref.read(accountsControllerProvider).activeAccount;
    if (account == null) return;
    final strategy = account.strategy;
    final lines = [
      if (strategy?.stayOutWhen case final w? when w.trim().isNotEmpty) w.trim(),
      insight.rule,
    ].join('\n');
    await accounts.save(
      account.copyWith(strategy: (strategy ?? const StrategyProfile()).copyWith(stayOutWhen: lines)),
    );
    _set(state.copyWith(ruled: {...state.ruled, insight.id}));
  }
}

final insightPrefsProvider = NotifierProvider<InsightPrefsController, InsightPrefs>(
  InsightPrefsController.new,
);

/// The active account's insights, or empty under [kInsightsFromTrades] trades.
final insightsProvider = Provider.autoDispose<List<Insight>>((ref) {
  final trades = ref.watch(activeAccountTradesProvider);
  if (trades.length < kInsightsFromTrades) return const [];
  return findInsights(trades);
});

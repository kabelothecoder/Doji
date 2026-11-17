import '../../accounts/domain/trading_account.dart';
import '../../onboarding/domain/profile_doji.dart';
import 'backtest.dart';

/// The things a draft can change, one at a time.
enum DraftChange {
  session('session'),
  stop('stop rule'),
  target('target'),
  condition('a condition on or off'),
  maxTrades('max trades');

  const DraftChange(this.label);

  final String label;
}

/// A copy of an account's strategy to try changes on. One change at a time:
/// after a change, the others wait until the draft is run again, so every
/// difference in the comparison has one cause.
class StrategyDraft {
  const StrategyDraft({
    required this.strategy,
    required this.rules,
    this.off = const {},
    this.pending,
    this.changes = const [],
    this.runs = 0,
    this.heldBackSeen = false,
  });

  /// From the account's current strategy, with default exits when it has none.
  factory StrategyDraft.of(TradingAccount account, {List<StrategyCondition>? conditions}) => StrategyDraft(
    strategy: (account.strategy ?? const StrategyProfile()).copyWith(
      conditions: conditions ?? account.strategy?.conditions ?? const [],
      exits: account.strategy?.exits ?? const ExitRules(),
    ),
    rules: account.rules,
  );

  final StrategyProfile strategy;
  final TradingRules? rules;

  /// Indexes of [StrategyProfile.conditions] switched off in this draft.
  final Set<int> off;

  /// The change made since the last run, if any.
  final DraftChange? pending;

  /// Each change, in words, in the order made ("target 2R → 3R").
  final List<String> changes;

  /// Times the draft was run on the tuning period.
  final int runs;

  /// The held-back period was used once; it is no longer unseen.
  final bool heldBackSeen;

  ExitRules get exits => strategy.exits ?? const ExitRules();

  List<StrategyCondition> get activeConditions => [
    for (var i = 0; i < strategy.conditions.length; i++)
      if (!off.contains(i)) strategy.conditions[i],
  ];

  /// A change of [kind] is open: nothing pending, or the same kind again.
  bool canChange(DraftChange kind) => pending == null || pending == kind;

  StrategyDraft _with(
    DraftChange kind,
    String words, {
    StrategyProfile? strategy,
    TradingRules? rules,
    Set<int>? off,
  }) {
    if (!canChange(kind)) return this;
    final list = [...changes];
    // Changing the same thing again before a run replaces the last line,
    // still measured from what was there at the last run.
    if (pending == kind && list.isNotEmpty) {
      final before = list.removeLast().split(' → ').first;
      words = '$before → ${words.split(' → ').last}';
    }
    return StrategyDraft(
      strategy: strategy ?? this.strategy,
      rules: rules ?? this.rules,
      off: off ?? this.off,
      pending: kind,
      changes: [...list, words],
      runs: runs,
      heldBackSeen: heldBackSeen,
    );
  }

  StrategyDraft setSession(String? key) {
    final i = strategy.conditions.indexWhere((c) => c.kind == ConditionKind.session);
    final next = [...strategy.conditions];
    final before = i < 0 ? null : next[i].session;
    if (i < 0) {
      next.insert(0, StrategyCondition(kind: ConditionKind.session, session: key));
    } else {
      next[i] = next[i].copyWith(session: key);
    }
    return _with(
      DraftChange.session,
      'session ${before ?? 'any of yours'} → ${key ?? 'any of yours'}',
      strategy: strategy.copyWith(conditions: next),
    );
  }

  StrategyDraft setStop(StopRule rule) => _with(
    DraftChange.stop,
    'stop ${exits.stop.label} → ${rule.label}',
    strategy: strategy.copyWith(exits: exits.copyWith(stop: rule)),
  );

  StrategyDraft setTargetR(double r) => _with(
    DraftChange.target,
    'target ${_n(exits.targetR)}R → ${_n(r)}R',
    strategy: strategy.copyWith(exits: exits.copyWith(targetR: r)),
  );

  StrategyDraft toggleCondition(int index, String label) {
    final next = {...off};
    final on = next.remove(index);
    if (!on) next.add(index);
    return _with(DraftChange.condition, '$label ${on ? 'on' : 'off'}', off: next);
  }

  StrategyDraft setMaxTrades(int max) => _with(
    DraftChange.maxTrades,
    'max trades ${rules?.maxTradesPerDay ?? 'not set'} → $max',
    rules: (rules ?? const TradingRules()).copyWith(maxTradesPerDay: max),
  );

  /// After a run on the tuning period: the next change opens.
  StrategyDraft ran() => StrategyDraft(
    strategy: strategy,
    rules: rules,
    off: off,
    changes: changes,
    runs: runs + 1,
    heldBackSeen: heldBackSeen,
  );

  StrategyDraft sawHeldBack() => StrategyDraft(
    strategy: strategy,
    rules: rules,
    off: off,
    pending: pending,
    changes: changes,
    runs: runs,
    heldBackSeen: true,
  );

  /// The strategy as it would be saved: switched-off conditions removed.
  StrategyProfile get adopted => strategy.copyWith(conditions: activeConditions);

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// The period a draft is tuned on and the part held back to check it on.
class Periods {
  const Periods({required this.from, required this.split, required this.to});

  /// [heldBackShare] of the time at the end is held back (0.3 = the last 30%).
  factory Periods.of(DateTime from, DateTime to, {double heldBackShare = 0.3}) {
    final ms = to.difference(from).inMilliseconds;
    return Periods(
      from: from,
      split: from.add(Duration(milliseconds: (ms * (1 - heldBackShare)).round())),
      to: to,
    );
  }

  final DateTime from;
  final DateTime split;
  final DateTime to;
}

/// Plain warnings for a comparison: small samples and tuning to one period.
List<String> fitWarnings({
  required BacktestStats current,
  required BacktestStats draft,
  required StrategyDraft d,
}) => [
  if (current.smallSample || draft.smallSample)
    'small sample: ${current.setups} and ${draft.setups} setups. under $kSmallSample, a difference can be chance.',
  if (d.changes.length > 1)
    'tested on the same period it was tuned on, ${d.changes.length} changes in. the more a strategy is tuned to one '
        'period, the more it fits that period only. check it on the held-back period.',
];

/// [account] with [draft] as its strategy; the one it replaces is kept as the
/// next numbered version.
TradingAccount adoptDraft(TradingAccount account, StrategyDraft draft, {required DateTime now}) =>
    account.copyWith(
      strategy: draft.adopted,
      rules: draft.rules,
      strategyVersions: [
        ...account.strategyVersions,
        StrategyVersion(
          number: account.strategyVersion,
          replacedAt: now.toUtc(),
          strategy: account.strategy,
          rules: account.rules,
          note: draft.changes.isEmpty
              ? 'replaced by a backtest draft'
              : 'replaced by a backtest draft: ${draft.changes.join(', ')}',
        ),
      ],
    );

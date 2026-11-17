import 'process_grade.dart';

enum TradeDirection {
  long('long', 1),
  short('short', -1);

  const TradeDirection(this.label, this.sign);

  final String label;

  /// +1 when a higher price is a gain, −1 when a lower price is.
  final int sign;

  static TradeDirection? fromName(String? name) =>
      TradeDirection.values.where((d) => d.name == name).firstOrNull;
}

/// "anxious · 7": what the trader felt before or after a trade.
class TradeEmotion {
  const TradeEmotion(this.name, this.intensity);

  final String name;

  /// 1–10.
  final int intensity;

  String get label => '$name $intensity';

  Map<String, Object?> toJson() => {'name': name, 'intensity': intensity};

  static TradeEmotion? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final intensity = json['intensity'];
    if (name is! String || intensity is! num) return null;
    return TradeEmotion(name, intensity.toInt().clamp(1, 10));
  }

  @override
  bool operator ==(Object other) =>
      other is TradeEmotion && other.name == name && other.intensity == intensity;

  @override
  int get hashCode => Object.hash(name, intensity);
}

/// What the trader says about a trade after it closed (the review sheet).
class TradeReview {
  const TradeReview({
    required this.setup,
    required this.plan,
    this.mistakes = const [],
    this.before,
    this.after,
    this.note = '',
  });

  final String setup;
  final PlanFollowed plan;
  final List<String> mistakes;
  final TradeEmotion? before;
  final TradeEmotion? after;
  final String note;
}

/// One closed trade in the journal.
///
/// [pnl] and [riskMoney] are in the account currency and are worked out once,
/// when the trade is saved (`TradeMath`), so a later change of rates never
/// rewrites history. [riskMoney] is null when the stop is unknown or the
/// instrument cannot be sized: R is then unavailable for this trade, and the
/// journal says so instead of guessing.
class Trade {
  const Trade({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.openedAt,
    required this.closedAt,
    required this.entry,
    required this.exit,
    required this.size,
    required this.pnl,
    this.stop,
    this.target,
    this.riskMoney,
    this.setup,
    this.plan,
    this.mistakes = const [],
    this.before,
    this.after,
    this.note = '',
    this.reviewedAt,
    this.source = 'manual',
    this.accountId,
    this.strategyVersion,
  });

  final String id;
  final String symbol;
  final TradeDirection direction;

  /// Instants (UTC). Shown on the trader's own clock.
  final DateTime openedAt;
  final DateTime closedAt;
  final double entry;
  final double exit;
  final double? stop;
  final double? target;

  /// Lots or contracts.
  final double size;

  /// Result in the account currency.
  final double pnl;

  /// What the stop put at risk, in the account currency.
  final double? riskMoney;

  final String? setup;
  final PlanFollowed? plan;
  final List<String> mistakes;
  final TradeEmotion? before;
  final TradeEmotion? after;
  final String note;
  final DateTime? reviewedAt;

  /// manual now; mt5, csv and broker later.
  final String source;

  /// The TradingAccount it was taken on. Null on trades saved before accounts:
  /// those show under "all accounts" only.
  final String? accountId;

  /// The account's strategy version when the trade was saved (`TradingAccount.strategyVersion`),
  /// so stats never mix two plans. Null on older trades.
  final int? strategyVersion;

  bool get reviewed => reviewedAt != null;
  bool get isWin => pnl > 0;
  bool get isLoss => pnl < 0;

  /// Result in R (units of the planned risk), or null when risk is unknown.
  double? get r {
    final risk = riskMoney;
    return risk == null || risk <= 0 ? null : pnl / risk;
  }

  /// Null until the trade is reviewed.
  ProcessGrade? get grade {
    final p = plan;
    if (!reviewed || p == null) return null;
    return ProcessGrade.of(plan: p, mistakes: mistakes, setup: setup);
  }

  /// This trade stamped with [version] (the journal does it on save).
  Trade withStrategyVersion(int? version) => Trade(
    id: id,
    symbol: symbol,
    direction: direction,
    openedAt: openedAt,
    closedAt: closedAt,
    entry: entry,
    exit: exit,
    size: size,
    pnl: pnl,
    stop: stop,
    target: target,
    riskMoney: riskMoney,
    setup: setup,
    plan: plan,
    mistakes: mistakes,
    before: before,
    after: after,
    note: note,
    reviewedAt: reviewedAt,
    source: source,
    accountId: accountId,
    strategyVersion: version,
  );

  Duration get timeInTrade => closedAt.difference(openedAt);

  Trade withReview(TradeReview review, DateTime at) => Trade(
    id: id,
    symbol: symbol,
    direction: direction,
    openedAt: openedAt,
    closedAt: closedAt,
    entry: entry,
    exit: exit,
    size: size,
    pnl: pnl,
    stop: stop,
    target: target,
    riskMoney: riskMoney,
    setup: review.setup,
    plan: review.plan,
    mistakes: review.mistakes,
    before: review.before,
    after: review.after,
    note: review.note,
    reviewedAt: at,
    source: source,
    accountId: accountId,
    strategyVersion: strategyVersion,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'symbol': symbol,
    'direction': direction.name,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'closedAt': closedAt.toUtc().toIso8601String(),
    'entry': entry,
    'exit': exit,
    'stop': stop,
    'target': target,
    'size': size,
    'pnl': pnl,
    'riskMoney': riskMoney,
    'setup': setup,
    'plan': plan?.name,
    'mistakes': mistakes,
    'before': before?.toJson(),
    'after': after?.toJson(),
    'note': note,
    'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
    'source': source,
    'accountId': accountId,
    'strategyVersion': strategyVersion,
  };

  /// Null for a record that is missing its essentials (skipped, never a crash).
  static Trade? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], symbol = json['symbol'];
    final direction = TradeDirection.fromName(json['direction'] as String?);
    final opened = DateTime.tryParse('${json['openedAt']}');
    final closed = DateTime.tryParse('${json['closedAt']}');
    final entry = json['entry'], exit = json['exit'], size = json['size'], pnl = json['pnl'];
    if (id is! String || symbol is! String || direction == null || opened == null || closed == null) {
      return null;
    }
    if (entry is! num || exit is! num || size is! num || pnl is! num) return null;
    final reviewed = json['reviewedAt'];
    final mistakes = json['mistakes'];
    return Trade(
      id: id,
      symbol: symbol,
      direction: direction,
      openedAt: opened.toUtc(),
      closedAt: closed.toUtc(),
      entry: entry.toDouble(),
      exit: exit.toDouble(),
      stop: (json['stop'] as num?)?.toDouble(),
      target: (json['target'] as num?)?.toDouble(),
      size: size.toDouble(),
      pnl: pnl.toDouble(),
      riskMoney: (json['riskMoney'] as num?)?.toDouble(),
      setup: json['setup'] as String?,
      plan: PlanFollowed.fromName(json['plan'] as String?),
      mistakes: mistakes is List ? mistakes.whereType<String>().toList() : const [],
      before: TradeEmotion.fromJson(json['before']),
      after: TradeEmotion.fromJson(json['after']),
      note: (json['note'] as String?) ?? '',
      reviewedAt: reviewed is String ? DateTime.tryParse(reviewed)?.toUtc() : null,
      source: (json['source'] as String?) ?? 'manual',
      accountId: json['accountId'] as String?,
      strategyVersion: (json['strategyVersion'] as num?)?.toInt(),
    );
  }
}

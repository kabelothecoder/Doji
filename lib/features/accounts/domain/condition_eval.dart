import '../../markets/domain/news.dart';
import '../../markets/domain/pair_brief.dart';
import '../../markets/domain/strategy_reading.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import 'trading_account.dart';

/// Suffix on every manual condition: doji shows it, never guesses it.
const kCheckOnYourChart = 'check on your chart';

/// The conditions onboarding gives a new account, from its parsed strategy:
/// the session, the two day limits, the entry (measured when it is a london
/// break, manual otherwise) and the news buffer.
List<StrategyCondition> defaultConditions(ParsedStrategy? parsed) {
  final reading = StrategyReading.of(parsed);
  final tf = reading.timeframe.label;
  final what = reading.entry ?? reading.setup;
  return [
    StrategyCondition(
      kind: ConditionKind.session,
      session: reading.kind == StrategyKind.londonBreak ? TradingSession.london.key : null,
    ),
    const StrategyCondition(kind: ConditionKind.tradesVsMax),
    const StrategyCondition(kind: ConditionKind.dailyLossVsLimit),
    if (reading.kind == StrategyKind.londonBreak)
      StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: reading.retest),
    if (reading.kind == StrategyKind.londonBreak && !reading.retest && reading.entry != null)
      StrategyCondition(kind: ConditionKind.manual, text: 'your entry: ${reading.entry} ($tf)'),
    if (reading.kind == StrategyKind.other && what != null)
      StrategyCondition(
        kind: ConditionKind.manual,
        text: 'your ${reading.entry != null ? 'entry' : 'setup'}: $what ($tf)',
      ),
    const StrategyCondition(kind: ConditionKind.newsBuffer),
  ];
}

/// What doji knows right now, to measure conditions against.
class ConditionFacts {
  const ConditionFacts({
    required this.now,
    required this.marketOpen,
    required this.traderSessions,
    required this.tradesToday,
    required this.lossTodayPct,
    this.maxTradesPerDay,
    this.dailyLossLimitPct,
    this.rangeBroke = false,
    this.closedBack = false,
    this.rangeOver = false,
    this.newsKnown = false,
    this.newsInWindow = false,
    this.timeframeLabel = 'M15',
  });

  /// UTC.
  final DateTime now;
  final bool marketOpen;

  /// profile.doji › sessions (keys).
  final List<String> traderSessions;
  final int tradesToday;
  final double lossTodayPct;
  final int? maxTradesPerDay;
  final double? dailyLossLimitPct;

  /// The london break, read from the candles.
  final bool rangeBroke;
  final bool closedBack;

  /// London is over for today: an unbroken range will not break today.
  final bool rangeOver;

  /// The instrument has news currencies (synthetics do not).
  final bool newsKnown;
  final bool newsInWindow;
  final String timeframeLabel;
}

/// The measured conditions, and the session they wait for (for "check again").
class MeasuredConditions {
  const MeasuredConditions(this.conditions, {this.waitingSession, this.sessionOpensAt});

  final List<EntryCondition> conditions;
  final TradingSession? waitingSession;
  final DateTime? sessionOpensAt;
}

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Measures [conditions] in their order. A condition doji has no data for
/// (no max set, no news currencies) is left out rather than guessed.
MeasuredConditions measureConditions(List<StrategyCondition> conditions, ConditionFacts f) {
  final out = <EntryCondition>[];
  TradingSession? waitingSession;
  DateTime? sessionOpensAt;
  if (!f.marketOpen && !conditions.any((c) => c.kind == ConditionKind.session)) {
    out.add(const EntryCondition('The market is open', ConditionStatus.notMet));
  }
  for (final c in conditions) {
    switch (c.kind) {
      case ConditionKind.session:
        if (!f.marketOpen) {
          out.add(const EntryCondition('The market is open', ConditionStatus.notMet));
          break;
        }
        final sessions = (c.session == null ? f.traderSessions : [c.session!])
            .map(TradingSession.fromKey)
            .whereType<TradingSession>()
            .where((s) => s.zoneId != null)
            .toList();
        if (sessions.isEmpty) {
          // No session preference ("around my job", or none): the market itself.
          out.add(const EntryCondition('The market is open', ConditionStatus.met));
          break;
        }
        final open = sessions.where((s) => s.isOpenAt(f.now)).firstOrNull;
        if (open != null) {
          out.add(EntryCondition('${open.label} session is open', ConditionStatus.met));
          break;
        }
        final next = [for (final s in sessions) (s, s.nextOpenAfter(f.now))]
          ..removeWhere((e) => e.$2 == null)
          ..sort((a, b) => a.$2!.compareTo(b.$2!));
        final s = next.isEmpty ? sessions.first : next.first.$1;
        out.add(
          EntryCondition(
            '${s.label} session is open',
            f.rangeOver ? ConditionStatus.notMet : ConditionStatus.waiting,
          ),
        );
        if (!f.rangeOver && next.isNotEmpty && waitingSession == null) {
          waitingSession = s;
          sessionOpensAt = next.first.$2;
        }
      case ConditionKind.tradesVsMax:
        final max = f.maxTradesPerDay;
        if (max == null) break;
        out.add(
          EntryCondition(
            'Trades today under your max of $max',
            f.tradesToday >= max ? ConditionStatus.notMet : ConditionStatus.met,
          ),
        );
      case ConditionKind.dailyLossVsLimit:
        final limit = f.dailyLossLimitPct;
        if (limit == null) break;
        final hit = f.lossTodayPct > 0 && f.lossTodayPct >= limit;
        out.add(
          EntryCondition(
            "Today's loss under your ${_n(limit)}% limit",
            hit ? ConditionStatus.notMet : ConditionStatus.met,
          ),
        );
      case ConditionKind.rangeBreak:
        final closed = f.rangeOver || !f.marketOpen;
        out.add(
          EntryCondition(
            'Price breaks the Asian range high or low',
            f.rangeBroke
                ? ConditionStatus.met
                : closed
                ? ConditionStatus.notMet
                : ConditionStatus.waiting,
          ),
        );
        if (c.closeBack) {
          out.add(
            EntryCondition(
              '${f.timeframeLabel} candle closes back beyond the broken level',
              f.closedBack
                  ? ConditionStatus.met
                  : closed
                  ? ConditionStatus.notMet
                  : ConditionStatus.waiting,
            ),
          );
        }
      case ConditionKind.newsBuffer:
        if (!f.newsKnown) break;
        out.add(
          EntryCondition(
            'No high-impact news within $kNewsBufferMinutes min',
            f.newsInWindow ? ConditionStatus.notMet : ConditionStatus.met,
          ),
        );
      case ConditionKind.manual:
        final text = c.text?.trim() ?? '';
        if (text.isEmpty) break;
        out.add(EntryCondition('${_cap(text)} · $kCheckOnYourChart', ConditionStatus.waiting));
    }
  }
  return MeasuredConditions(out, waitingSession: waitingSession, sessionOpensAt: sessionOpensAt);
}

/// The editor's one-line name for a condition.
String conditionLabel(StrategyCondition c) => switch (c.kind) {
  ConditionKind.session =>
    c.session == null
        ? 'one of your sessions is open'
        : '${TradingSession.fromKey(c.session!)?.label.toLowerCase() ?? c.session} session is open',
  ConditionKind.newsBuffer => 'no high-impact news within $kNewsBufferMinutes min',
  ConditionKind.tradesVsMax => 'trades today under your max',
  ConditionKind.dailyLossVsLimit => "today's loss under your limit",
  ConditionKind.rangeBreak =>
    c.closeBack ? 'asian range breaks, then a candle closes back beyond it' : 'price breaks the asian range',
  ConditionKind.manual => '${c.text ?? ''} · $kCheckOnYourChart',
};

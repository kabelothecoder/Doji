import '../../journal/domain/journal_stats.dart';
import '../../journal/domain/trade.dart';
import '../../onboarding/domain/profile_doji.dart';

/// Who said a line in a coach session.
enum CoachSpeaker { you, coach }

/// One line of a session transcript.
class CoachTurn {
  const CoachTurn({required this.speaker, required this.text, required this.at});

  final CoachSpeaker speaker;
  final String text;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'speaker': speaker.name,
    'text': text,
    'at': at.toUtc().toIso8601String(),
  };

  /// Null when the record is not a turn (skipped, never fatal).
  static CoachTurn? fromJson(Object? json) {
    if (json is! Map) return null;
    final speaker = CoachSpeaker.values.asNameMap()[json['speaker']];
    final text = json['text'];
    final at = DateTime.tryParse('${json['at']}');
    if (speaker == null || text is! String || at == null) return null;
    return CoachTurn(speaker: speaker, text: text, at: at);
  }
}

/// The three coach voices. [value] is what profile.doji stores (the
/// onboarding coach step); [short] is the session's voice picker.
enum CoachVoice {
  calmMale('calm_male', 'male', 'calm male'),
  calmFemale('calm_female', 'female', 'calm female'),
  coachTone('coach_tone', 'coach', 'coach tone');

  const CoachVoice(this.value, this.short, this.label);

  final String value;
  final String short;
  final String label;

  /// The stored voice, else coach tone (the one the design shows picked).
  static CoachVoice of(String? value) =>
      values.firstWhere((v) => v.value == value, orElse: () => CoachVoice.coachTone);
}

/// What doji knows about the trader right now, for the coach to speak to.
/// Built from profile.doji and today's journal; a field doji does not know is
/// null, and the coach then asks instead of assuming.
class CoachContext {
  const CoachContext({
    this.name,
    this.setup,
    this.entry,
    this.riskPerTradePct,
    this.maxTradesPerDay,
    this.dailyLossLimitPct,
    this.struggles = const [],
    this.tradesToday = 0,
    this.lossStreak = 0,
    this.lossTodayPct = 0,
  });

  final String? name;

  /// The parsed strategy's setup ("london break") and entry rule ("M15 retest").
  final String? setup;
  final String? entry;

  final double? riskPerTradePct;
  final int? maxTradesPerDay;

  /// The stricter of the trader's own daily loss limit and the prop firm's.
  final double? dailyLossLimitPct;

  /// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
  final List<String> struggles;

  final int tradesToday;

  /// Losses in a row, counting back from the latest trade today.
  final int lossStreak;

  /// Today's loss as a percent of the account (0 when flat or up).
  final double lossTodayPct;

  factory CoachContext.from(ProfileDoji p, {required List<Trade> trades, required DateTime now}) {
    final day = DaySummary.of(trades, now);
    final rules = p.rules;
    final parsed = p.strategy?.parsed;
    final limits = [rules?.dailyLossLimit, p.prop?.dailyLossLimitPct].whereType<double>();
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    return CoachContext(
      name: clean(p.name),
      setup: clean(parsed?.setup),
      entry: clean(parsed?.entry),
      riskPerTradePct: rules?.riskPerTrade,
      maxTradesPerDay: rules?.maxTradesPerDay,
      dailyLossLimitPct: limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b),
      struggles: p.struggles,
      tradesToday: day.count,
      lossStreak: day.lossStreak,
      lossTodayPct: day.lossPercent(
        accountSize: p.prop?.accountSize?.toDouble(),
        riskPerTradePct: rules?.riskPerTrade ?? 1.0,
      ),
    );
  }
}

/// The coach behind the session screen. The UI only sees this.
///
/// A coach never says what the market will do or what to trade: it points the
/// trader back to their own plan and rules (CLAUDE.md, no buy/sell language).
abstract interface class Coach {
  /// The first line when a session opens.
  Future<String> opener(CoachContext context);

  /// The reply to [message]. [history] is the session so far, oldest first,
  /// without [message].
  Future<String> reply(CoachContext context, List<CoachTurn> history, String message);
}

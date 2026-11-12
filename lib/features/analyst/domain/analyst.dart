import '../../markets/domain/pair_brief.dart';
import 'aggregates.dart';

/// The rule a review asks the trader to focus on, by the tag that broke it.
const Map<String, String> kFocusRules = {
  'moved stop': 'leave the stop where you placed it',
  'early exit': 'let each trade reach your stop or your target',
  'late entry': 'enter where your plan says, or skip the trade',
  'oversized': 'size every trade at your risk per trade',
  'revenge': 'after a loss, wait an hour before the next trade',
  'FOMO': 'only take setups your plan names',
  'no setup': 'only take setups your plan names',
  'against plan': 'take only what your written plan allows',
  'news spike': 'no entries around high-impact news',
  'overtrading': 'stop at your max trades a day',
};

/// The rule to focus on next: the most used break tag, or max trades when
/// more days went past it than any tag was used. Null when nothing broke.
String? focusRuleFor(AnalystFacts f) {
  final top = f.breaksByTag.firstOrNull;
  final days = f.maxTradesBreaks.length;
  if (days > 0 && (top == null || days > top.count)) return kFocusRules['overtrading'];
  return top == null ? null : kFocusRules[top.tag];
}

/// A week's written review, stored on the device.
class WeeklyReview {
  const WeeklyReview({
    required this.accountId,
    required this.weekStart,
    required this.kept,
    required this.broke,
    required this.focusRule,
    this.accepted = false,
  });

  final String accountId;

  /// Local Monday of the week reviewed.
  final DateTime weekStart;
  final String kept;
  final String broke;

  /// Null when nothing was broken.
  final String? focusRule;

  /// The trader took the focus rule for the week: shown on Home and the rail.
  final bool accepted;

  WeeklyReview accept() => WeeklyReview(
    accountId: accountId,
    weekStart: weekStart,
    kept: kept,
    broke: broke,
    focusRule: focusRule,
    accepted: true,
  );

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'weekStart': '${weekStart.year}-${weekStart.month}-${weekStart.day}',
    'kept': kept,
    'broke': broke,
    'focusRule': focusRule,
    'accepted': accepted,
  };

  static WeeklyReview? fromJson(Object? j) {
    if (j is! Map) return null;
    final week = (j['weekStart'] as String?)?.split('-').map(int.tryParse).toList();
    if (j['accountId'] is! String || j['kept'] is! String || j['broke'] is! String) return null;
    if (week == null || week.length != 3 || week.contains(null)) return null;
    return WeeklyReview(
      accountId: j['accountId'] as String,
      weekStart: DateTime(week[0]!, week[1]!, week[2]!),
      kept: j['kept'] as String,
      broke: j['broke'] as String,
      focusRule: j['focusRule'] as String?,
      accepted: j['accepted'] == true,
    );
  }
}

/// A note or file the trader added about their strategy, per account.
class AccountSource {
  const AccountSource({
    required this.id,
    required this.accountId,
    required this.title,
    required this.addedAt,
    this.text = '',
    this.fileName,
  });

  final String id;
  final String accountId;
  final String title;
  final DateTime addedAt;

  /// The note's words ('' for a file).
  final String text;

  /// A PDF's file name; its words are read once sync is on.
  final String? fileName;

  bool get isFile => fileName != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'title': title,
    'addedAt': addedAt.toUtc().toIso8601String(),
    'text': text,
    'fileName': fileName,
  };

  static AccountSource? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse(j['addedAt'] as String? ?? '');
    if (j['id'] is! String || j['accountId'] is! String || j['title'] is! String || at == null) return null;
    return AccountSource(
      id: j['id'] as String,
      accountId: j['accountId'] as String,
      title: j['title'] as String,
      addedAt: at,
      text: j['text'] as String? ?? '',
      fileName: j['fileName'] as String?,
    );
  }
}

/// Reads the trader's own numbers back to them. Doji counts; the analyst only
/// explains the counts and asks questions. It never says where price goes.
abstract interface class Analyst {
  /// [week]: facts for the trades of the week starting [weekStart].
  Future<WeeklyReview> weeklyReview({
    required String accountId,
    required DateTime weekStart,
    required AnalystFacts week,
  });

  Future<String> reply(AnalystFacts facts, List<BriefTurn> history, String message);
}

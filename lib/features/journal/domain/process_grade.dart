/// How the trader followed their plan, as answered in the review.
enum PlanFollowed {
  yes,
  partly,
  no;

  static PlanFollowed? fromName(String? name) => PlanFollowed.values.where((p) => p.name == name).firstOrNull;
}

/// The ten mistake tags a review offers (Doji Trade Journal › MistakeTagChip).
const List<String> kMistakeTags = [
  'moved stop',
  'early exit',
  'late entry',
  'oversized',
  'revenge',
  'FOMO',
  'no setup',
  'against plan',
  'news spike',
  'overtrading',
];

/// The eight emotions before and after a trade.
const List<String> kJournalEmotions = [
  'calm',
  'focused',
  'confident',
  'anxious',
  'angry',
  'frustrated',
  'bored',
  'tired',
];

/// The setup name for a trade that matched none of the trader's setups.
const String kNoSetup = 'no setup';

/// Process grade A–F: how well the plan was followed, never how the trade
/// ended. A losing trade that kept the plan can be an A.
enum ProcessGrade {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  f('F');

  const ProcessGrade(this.letter);

  final String letter;

  /// A and B: the plan was kept.
  bool get keptPlan => this == a || this == b;

  /// D and F: the plan was broken.
  bool get brokePlan => this == d || this == f;

  /// Doji Trade Journal › `gradeOf`. No setup is always an F, even on a win.
  static ProcessGrade of({required PlanFollowed plan, required List<String> mistakes, String? setup}) {
    if (setup == kNoSetup) return f;
    return switch (plan) {
      PlanFollowed.yes => mistakes.isEmpty ? a : b,
      PlanFollowed.partly => mistakes.length > 2 ? d : c,
      PlanFollowed.no => mistakes.length > 1 ? f : d,
    };
  }
}

/// One line of "process grade" on the trade detail: a check that was kept or broken.
class ProcessReason {
  const ProcessReason(this.text, {required this.kept});

  final String text;
  final bool kept;
}

/// The five checks behind the grade, read from the review's tags.
List<ProcessReason> processReasons({
  required String? setup,
  required List<String> mistakes,
  double? riskPercent,
}) {
  final hasSetup = setup != null && setup != kNoSetup && !mistakes.contains('no setup');
  final moved = mistakes.contains('moved stop');
  final early = mistakes.contains('early exit');
  final risk = riskPercent == null ? '[1]' : _trim(riskPercent);
  return [
    ProcessReason(hasSetup ? 'setup matched: $setup' : 'no setup from your strategy', kept: hasSetup),
    ProcessReason('size within $risk% risk', kept: !mistakes.contains('oversized')),
    ProcessReason(
      'entry on the trigger',
      kept: !mistakes.contains('late entry') && !mistakes.contains('FOMO'),
    ),
    ProcessReason(moved ? 'stop moved after entry' : 'stop left where planned', kept: !moved),
    ProcessReason(early ? 'closed before target' : 'exit followed the plan', kept: !early),
  ];
}

String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// What the review says about a trade, from its tags. Plain text about this
/// trade only, never the market. (Doji Trade Journal › TAGP.)
class TradeReviewNotes {
  const TradeReviewNotes({required this.right, required this.broke, required this.lesson});

  final String right;
  final String broke;
  final String lesson;

  static const Map<String, (String, String)> _byTag = {
    'moved stop': ('stop moved after entry', 'once the stop is set, it only moves toward profit.'),
    'early exit': ('closed before target', 'let the plan decide the exit.'),
    'late entry': ('entered after the trigger candle', 'if the trigger is gone, so is the trade.'),
    'oversized': ('size above your risk', 'size comes from the stop, not the feeling.'),
    'revenge': ('entered right after a loss', 'after a loss, wait before the next entry.'),
    'FOMO': ('chased a move already running', 'no setup, no trade, even when it wins.'),
    'no setup': ('no setup from your strategy', 'no setup, no trade, even when it wins.'),
    'against plan': ('went against the plan', 'if the plan says no, the answer is no.'),
    'news spike': ('entered inside the news window', 'stay out of the news window you set.'),
    'overtrading': ('took more trades than planned', 'the trade limit is part of the plan.'),
  };

  factory TradeReviewNotes.of({required String? setup, required List<String> mistakes, required bool won}) {
    final known = [
      for (final t in mistakes)
        if (_byTag.containsKey(t)) t,
    ];
    final first = known.firstOrNull;
    final hasSetup = setup != null && setup != kNoSetup;
    return TradeReviewNotes(
      right: hasSetup
          ? 'the setup matched your $setup rules.'
          : 'no setup from your strategy was present${won ? ', even though the trade won' : ''}.',
      broke: first == null
          ? 'nothing. this one went by the plan.'
          : '${_byTag[first]!.$1}${known.length > 1 ? ', then ${_byTag[known[1]]!.$1}' : ''}.',
      lesson: first == null
          ? (won ? 'repeat exactly this.' : 'a planned loss is a good trade. keep taking these.')
          : _byTag[first]!.$2,
    );
  }
}

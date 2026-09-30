// The onboarding script. Copy is verbatim from design/handoff/Doji
// Onboarding.dc.html where the handoff has it; lines marked `// doji voice`
// were written for answers the handoff doesn't show (it gives one example
// reply per step). No buy/sell language, no promises, no invented stats.
import 'onboarding_step.dart';
import 'risk.dart';
import 'sessions.dart';

/// Answer shapes, by step id:
/// - name: String
/// - experience, style: String (option value)
/// - markets, sessions, struggles: `List<String>`
/// - timeZone: {id: String, offsetMinutes: int} (detected, editable)
/// - goal: {goal: String, propFirm: String?, propSize: int?}
/// - strategy: {raw: String?, template: String?, source: text|voice|template}
/// - strategyParsed: {setup, timeframe, entry, stop, target}
/// - risk: {riskPct: num, maxTrades: int, dailyLoss: num}
/// - coach: {voice: String, name: String?}
/// - ritual: {time: 'HH:mm', notifications: granted|denied|deferred}
/// - rules, compile: true · pledge: {pledgedAt: ISO-8601}
abstract final class StepIds {
  static const boot = 'boot';
  static const manifesto = 'manifesto';
  static const name = 'name';
  static const experience = 'experience';
  static const style = 'style';
  static const markets = 'markets';
  static const sessions = 'sessions';
  static const timeZone = 'timeZone';
  static const goal = 'goal';
  static const struggles = 'struggles';
  static const strategy = 'strategy';
  static const strategyParsed = 'strategyParsed';
  static const risk = 'risk';
  static const rules = 'rules';
  static const coach = 'coach';
  static const ritual = 'ritual';
  static const compile = 'compile';
  static const pledge = 'pledge';
  static const save = 'save';
}

enum SecondaryAction { none, skip, signIn, declineNotifications }

SecondaryAction secondaryFor(OnboardingStep s) => switch (s.id) {
  StepIds.boot => SecondaryAction.signIn,
  StepIds.ritual => SecondaryAction.declineNotifications,
  _ => s.skippable ? SecondaryAction.skip : SecondaryAction.none,
};

// --- Options -----------------------------------------------------------------

const experienceOptions = [
  StepOption('lt_6m', '<6 months'),
  StepOption('6_24m', '6–24 months'),
  StepOption('2_5y', '2–5 years'),
  StepOption('5y_plus', '5+ years'),
];

const styleOptions = [
  StepOption('scalper', 'scalper'),
  StepOption('day_trader', 'day trader'),
  StepOption('swing', 'swing'),
  StepOption('undecided', 'not sure yet'),
];

const marketOptions = [
  StepOption('XAUUSD', 'XAUUSD', mono: true),
  StepOption('EURUSD', 'EURUSD', mono: true),
  StepOption('GBPUSD', 'GBPUSD', mono: true),
  StepOption('USDJPY', 'USDJPY', mono: true),
  StepOption('NAS100', 'NAS100', mono: true),
  StepOption('US30', 'US30', mono: true),
  StepOption('BTCUSD', 'BTCUSD', mono: true),
];

/// "Search matches broker aliases (GOLD, XAU/USD)."
const marketAliases = <String, List<String>>{
  'XAUUSD': ['GOLD', 'XAU/USD', 'XAU'],
  'EURUSD': ['EUR/USD', 'EURO', 'FIBER'],
  'GBPUSD': ['GBP/USD', 'CABLE', 'POUND'],
  'USDJPY': ['USD/JPY', 'YEN', 'GOPHER'],
  'NAS100': ['NASDAQ', 'US100', 'USTEC', 'NDX'],
  'US30': ['DOW', 'DJ30', 'WS30', 'DJI'],
  'BTCUSD': ['BITCOIN', 'BTC', 'BTC/USD', 'XBT'],
};

final sessionOptions = [for (final s in TradingSession.values) StepOption(s.key, s.label)];

const goalOptions = [
  StepOption('prop_challenge', 'pass a prop challenge'),
  StepOption('grow_account', 'grow my account'),
  StepOption('consistent', 'be consistent'),
  StepOption('make_it_my_job', 'make this my job'),
  StepOption('learn', 'learn properly'),
];

const propSizes = [10000, 25000, 50000, 100000, 200000];

const struggleOptions = [
  StepOption('revenge', 'revenge trading'),
  StepOption('fomo', 'FOMO'),
  StepOption('overtrading', 'overtrading'),
  StepOption('hesitation', 'hesitation'),
  StepOption('moving_stop', 'moving my stop'),
  StepOption('oversizing', 'oversizing'),
  StepOption('bored', 'trading when bored'),
];

const riskOptions = [
  StepOption('0.5', '0.5%', mono: true),
  StepOption('1', '1%', mono: true),
  StepOption('2', '2%', mono: true),
  StepOption('custom', 'custom', mono: true),
];

const voiceOptions = [
  StepOption('calm_male', 'calm male'),
  StepOption('calm_female', 'calm female'),
  StepOption('coach_tone', 'coach tone'),
];

String labelFor(List<StepOption> options, String? value) =>
    options.where((o) => o.value == value).firstOrNull?.label ?? (value ?? '');

// --- Validation (doji voice) -------------------------------------------------

String? _required(Object? v, String message) {
  if (v == null) return message;
  if (v is String && v.trim().isEmpty) return message;
  if (v is List && v.isEmpty) return message;
  return null;
}

// --- Replies -----------------------------------------------------------------

const _marketNames = {
  'XAUUSD': 'gold',
  'NAS100': 'nasdaq',
  'US30': 'the dow',
  'BTCUSD': 'bitcoin',
  'EURUSD': 'euro',
  'GBPUSD': 'cable',
  'USDJPY': 'yen',
};
const _fastMovers = {'XAUUSD', 'NAS100', 'US30', 'BTCUSD'};

String _joinAnd(List<String> xs) =>
    xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

String? marketsReply(Object? answer, Answers _) {
  final picked = answer is List ? answer.whereType<String>().toList() : const <String>[];
  if (picked.isEmpty) return null;
  if (picked.length > 3) return '${picked.length} markets. noted.'; // doji voice
  final names = _joinAnd([for (final p in picked) _marketNames[p] ?? p.toLowerCase()]);
  if (picked.every(_fastMovers.contains)) {
    final who = switch (picked.length) {
      1 => 'it moves',
      2 => 'both move',
      _ => 'they move',
    };
    return "$names. $who fast — we'll keep you steady.";
  }
  return '$names. noted.'; // doji voice
}

String? sessionsReply(Object? answer, Answers answers) {
  final keys = answer is List ? answer.whereType<String>().toList() : const <String>[];
  if (keys.isEmpty) return null;
  final offset = (A.mapNum(answers[StepIds.timeZone], 'offsetMinutes') ?? 0).round();
  final first = firstSession(keys, offset);
  if (first == null) return "around your job. we'll fit the open to your day."; // doji voice
  return "${first.label.toLowerCase()}, ${hhmm(first.localOpen(offset)!)} your time. i'll be there.";
}

/// Doji's reply to the goal answer. The handoff defines the prop line; the
/// others are written in the same voice (calm, honest, no promises).
String? goalReply(Object? answer, Answers _) {
  final goal = A.mapStr(answer, 'goal');
  return switch (goal) {
    'prop_challenge' => 'a prop challenge. rules matter even more there.',
    'grow_account' => 'growing the account. that starts with keeping it.', // doji voice
    'consistent' => "consistency. that's most of the game.", // doji voice
    'make_it_my_job' => 'a job needs a routine. we can build one.', // doji voice
    'learn' => "learning properly. we'll go one step at a time.", // doji voice
    _ => null,
  };
}

String? strugglesReply(Object? answer, Answers _) {
  final picked = answer is List ? answer.whereType<String>().toList() : const <String>[];
  final first = struggleOptions.where((o) => picked.contains(o.value)).firstOrNull;
  if (first == null) return null;
  return "${first.label}. noted. we'll handle that together.";
}

bool hasStrategyToReview(Answers a) {
  final s = a[StepIds.strategy];
  final raw = A.mapStr(s, 'raw');
  final template = A.mapStr(s, 'template');
  return raw != null || (template != null && template != 'none');
}

// --- The script --------------------------------------------------------------

List<OnboardingStep> buildOnboardingSteps() => [
  const OnboardingStep(
    id: StepIds.boot,
    view: StepView.boot,
    input: StepInput.info,
    prompt: "hey. i'm doji.",
    sub: "let's set you up — about 3 minutes.",
    cta: "let's go",
    skipLabel: 'I already have an account',
    skippable: false,
    showConfig: false,
    countsAsAnswer: false,
  ),
  const OnboardingStep(
    id: StepIds.manifesto,
    view: StepView.manifesto,
    input: StepInput.info,
    prompt: 'There is no holy grail.',
    sub: 'There is balance.',
    cta: "I'm in",
    skippable: false,
    showConfig: false,
    countsAsAnswer: false,
  ),
  OnboardingStep(
    id: StepIds.name,
    view: StepView.question,
    input: StepInput.text,
    prompt: 'what should I call you?',
    validate: (v) => _required(v, 'i need something to call you. a nickname works.'), // doji voice
    reply: (v, _) => v is String && v.trim().isNotEmpty ? '${v.trim()}. good to meet you.' : null,
  ),
  OnboardingStep(
    id: StepIds.experience,
    view: StepView.question,
    input: StepInput.single,
    prompt: 'how long have you been trading?',
    options: experienceOptions,
    autoAdvance: true,
    validate: (v) => _required(v, 'pick one to continue, or skip it for now.'), // doji voice
    reply: (v, _) => switch (v) {
      '6_24m' => '6–24 months. the stretch where habits get set.',
      'lt_6m' => 'under 6 months. the best time to build habits.', // doji voice
      '2_5y' => '2–5 years. long enough to know your patterns.', // doji voice
      '5y_plus' => "5+ years. you know the game. we'll tighten the edges.", // doji voice
      _ => null,
    },
  ),
  OnboardingStep(
    id: StepIds.style,
    view: StepView.question,
    input: StepInput.single,
    prompt: 'how do you trade?',
    options: styleOptions,
    autoAdvance: true,
    validate: (v) => _required(v, 'pick one to continue, or skip it for now.'),
    reply: (v, _) => switch (v) {
      'undecided' => "not sure yet. fair — i'll ask again in two weeks.", // from the handoff note
      'swing' => 'swing trader. noted.', // doji voice
      final String s => '${labelFor(styleOptions, s)}. noted.',
      _ => null,
    },
  ),
  OnboardingStep(
    id: StepIds.markets,
    view: StepView.question,
    input: StepInput.multi,
    prompt: 'what do you trade?',
    sub: 'pick any.',
    options: marketOptions,
    validate: (v) => _required(v, 'pick at least one, or skip it for now.'),
    reply: marketsReply,
  ),
  OnboardingStep(
    id: StepIds.sessions,
    view: StepView.question,
    input: StepInput.multi,
    prompt: 'when do you trade?',
    options: sessionOptions,
    validate: (v) => _required(v, 'pick at least one, or skip it for now.'),
    reply: sessionsReply,
  ),
  OnboardingStep(
    id: StepIds.goal,
    view: StepView.question,
    input: StepInput.custom,
    prompt: 'what are you working toward?',
    options: goalOptions,
    columns: 1,
    configWindow: 1,
    validate: (v) => A.mapStr(v, 'goal') == null ? 'pick one to continue, or skip it for now.' : null,
    reply: goalReply,
  ),
  OnboardingStep(
    id: StepIds.struggles,
    view: StepView.question,
    input: StepInput.multi,
    prompt: 'be honest — what usually gets you?',
    sub: 'pick any. this stays between us.',
    options: struggleOptions,
    validate: (v) => _required(v, 'pick at least one, or skip it for now.'),
    reply: strugglesReply,
  ),
  OnboardingStep(
    id: StepIds.strategy,
    view: StepView.question,
    input: StepInput.voiceOrText,
    prompt: 'describe your strategy in your own words',
    cta: 'read it',
    configWindow: 1,
    validate: (v) => A.mapStr(v, 'raw') == null && A.mapStr(v, 'template') == null
        ? 'describe it in a line or two, or pick a template.' // doji voice
        : null,
    reply: (v, a) => hasStrategyToReview({StepIds.strategy: v})
        ? 'got it. check what i understood.'
        : "no strategy yet is fine. we'll write one together.", // doji voice
  ),
  OnboardingStep(
    id: StepIds.strategyParsed,
    view: StepView.question,
    input: StepInput.custom,
    prompt: 'your strategy, structured',
    cta: 'looks right',
    configWindow: 1,
    condition: hasStrategyToReview,
    reply: (_, _) => "your plan, in writing. that's the hard part done.",
  ),
  OnboardingStep(
    id: StepIds.risk,
    view: StepView.question,
    input: StepInput.stepper,
    prompt: 'how much will you risk per trade?',
    options: riskOptions,
    columns: 4,
    configWindow: 1,
    validate: (v) => A.mapNum(v, 'riskPct') == null ? 'pick a risk per trade to continue.' : null,
    reply: (v, _) {
      final r = A.mapNum(v, 'riskPct');
      if (r == null) return null;
      return riskNote(r) != null
          ? '${fmtPct(r)}% a trade. noted, and i will remind you.'
          : "${fmtPct(r)}% a trade. that's room to be wrong.";
    },
  ),
  OnboardingStep(
    id: StepIds.rules,
    view: StepView.question,
    input: StepInput.info,
    prompt: 'here are your rules.',
    cta: 'these are my rules',
    skippable: false,
    configWindow: 1,
    reply: (_, _) => 'rules saved. now pick who you will hear.',
  ),
  OnboardingStep(
    id: StepIds.coach,
    view: StepView.question,
    input: StepInput.custom,
    prompt: 'which voice should coach you?',
    options: voiceOptions,
    columns: 1,
    configWindow: 1,
    validate: (v) => A.mapStr(v, 'voice') == null ? 'pick a voice to continue, or skip it for now.' : null,
    reply: (v, _) => switch (A.mapStr(v, 'voice')) {
      'calm_female' => 'calm female. she sounds like this at the open.',
      'calm_male' => 'calm male. he sounds like this at the open.', // doji voice
      'coach_tone' => 'coach tone. it sounds like this at the open.', // doji voice
      _ => null,
    },
  ),
  const OnboardingStep(
    id: StepIds.ritual,
    view: StepView.question,
    input: StepInput.time,
    prompt: 'when should we do your open?',
    sub: '60 seconds before your session.',
    cta: 'allow notifications',
    skipLabel: 'not now',
    columns: 3,
    configWindow: 1,
    optionsFor: ritualOptions,
  ),
  const OnboardingStep(
    id: StepIds.compile,
    view: StepView.compile,
    input: StepInput.info,
    prompt: 'compiling profile.doji…',
    skippable: false,
    showConfig: false,
    countsAsAnswer: false,
  ),
  const OnboardingStep(
    id: StepIds.pledge,
    view: StepView.pledge,
    input: StepInput.custom,
    prompt: 'your plan,\nnot your feelings.',
    skippable: false,
    showConfig: false,
  ),
  const OnboardingStep(
    id: StepIds.save,
    view: StepView.save,
    input: StepInput.info,
    skippable: false,
    showConfig: false,
    countsAsAnswer: false,
  ),
];

/// "The Open time, defaulting to 30 minutes before their first session."
List<StepOption> ritualOptions(Answers answers) {
  final offset = (A.mapNum(answers[StepIds.timeZone], 'offsetMinutes') ?? 0).round();
  final ref = openReferenceMinutes(A.list(answers, StepIds.sessions), offset);
  return [
    StepOption(hhmm(ref - 30), hhmm(ref - 30), sub: '30m before', mono: true),
    StepOption(hhmm(ref - 15), hhmm(ref - 15), sub: '15m before', mono: true),
    StepOption(hhmm(ref), hhmm(ref), sub: 'at the open', mono: true),
  ];
}

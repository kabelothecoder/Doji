// The mind toolkit's fixed content (design: Doji Me Phone › prompts, affirmations, reading).
// Copy marked "design" is verbatim from the design; the rest is doji voice. Lowercase, calm,
// no buy/sell language, no promises about results. Change the content here, not in the UI.
//
// TODO(backend): content feed. Reading cards and articles come from the server once it runs;
// these stay as the offline set.

/// One reflection prompt card.
class MindPrompt {
  const MindPrompt(this.id, this.text);

  final String id;
  final String text;
}

/// One affirmation. [own] = written by the trader (stored, can be deleted).
class Affirmation {
  const Affirmation(this.id, this.text, {this.own = false});

  final String id;
  final String text;
  final bool own;
}

/// A short article doji wrote, or a book the coach draws from ([author] set, no [paragraphs]).
class ReadingCard {
  const ReadingCard({
    required this.id,
    required this.title,
    required this.summary,
    this.minutes,
    this.author,
    this.paragraphs = const [],
  });

  final String id;
  final String title;
  final String summary;
  final int? minutes;
  final String? author;
  final List<String> paragraphs;

  bool get isBook => author != null;
}

const List<MindPrompt> kMindPrompts = [
  MindPrompt('want', 'what did you want the market to give you today?'), // design
  MindPrompt('heaviest', 'which rule felt heaviest this week, and why?'), // design
  MindPrompt('friend', 'what would you tell a friend after the trade you just took?'), // design
  MindPrompt('calm', 'when did you feel most calm at the screen?'), // design
  MindPrompt('skip', 'which setup did you let pass, and how did that feel?'),
  MindPrompt('before', 'what was in your body just before your last entry?'),
  MindPrompt('stop', 'what made it easy, or hard, to stop for the day?'),
  MindPrompt('again', 'which trade would you take again exactly the same way?'),
  MindPrompt('rule', 'which of your rules do you trust most right now?'),
  MindPrompt('rest', 'what helps you switch off after the session?'),
];

const List<Affirmation> kAffirmations = [
  Affirmation('job', "i don't need to trade to be doing my job."), // design
  Affirmation('skipped', 'a skipped setup is a kept promise.'), // design
  Affirmation('rules', "my rules decide. my mood doesn't."), // design
  Affirmation('cost', 'losses are a cost of the job, not a verdict on me.'), // design
  Affirmation('stop-day', 'i can stop for the day and still be a trader.'), // design
  Affirmation('slow', 'slow is fine. i only need my setup.'),
  Affirmation('one', 'one trade is one trade. it does not define the week.'),
  Affirmation('wait', 'waiting is part of the plan.'),
  Affirmation('size', 'my size stays the same when i feel sure.'),
  Affirmation('close', 'closing the screen is a skill.'),
  Affirmation('process', 'i judge my day by how i followed the plan.'),
  Affirmation('breathe', 'one breath before every click.'),
];

const List<ReadingCard> kReading = [
  ReadingCard(
    id: 'after-a-loss',
    title: 'the hour after a loss',
    summary: 'why the next trade feels urgent, and what to do instead.',
    minutes: 2,
    paragraphs: [
      'a loss makes the next setup look better than it is. the mind wants the number back, and it '
          'starts to see your entry everywhere.',
      'that pull is normal. it is not a reason to act on it.',
      'a simple rule helps: after a loss, stand up, look away from the chart and wait ten minutes '
          'before you read the next setup.',
      'if the setup is still there and still matches your plan, it will be there in ten minutes.',
    ],
  ),
  ReadingCard(
    id: 'process-not-outcome',
    title: 'grade the process, not the result',
    summary: 'a losing trade can be an A. a winning one can be an F.',
    minutes: 2,
    paragraphs: [
      'one trade tells you very little about your edge. how you took it tells you a lot about you.',
      'doji grades each trade by the plan: did you take your setup, place your stop, keep your size.',
      'a loss that kept every rule is a good day of work. a win that broke them is a habit you '
          'are paying for later.',
    ],
  ),
  ReadingCard(
    id: 'walk-away',
    title: 'why walking away counts',
    summary: 'stopping at your limit is part of the plan, not a pause from it.',
    minutes: 2,
    paragraphs: [
      'a daily limit only works if you stop when you reach it, on good days and bad ones.',
      'the urge to keep going is strongest right after the limit. that is when the rule matters most.',
      'close the platform, write one line in the journal, and let the day be done.',
    ],
  ),
  ReadingCard(
    id: 'boredom',
    title: 'boredom is not a setup',
    summary: 'quiet sessions are where most rules get broken.',
    minutes: 1,
    paragraphs: [
      'when nothing happens for an hour, a weak setup starts to look fine.',
      'name it: "i am bored." then check the setup against your written rules, line by line.',
      'if one line is missing, the answer is no. that is a kept promise, not a missed chance.',
    ],
  ),
  ReadingCard(
    id: 'zone',
    title: 'Trading in the Zone',
    author: 'Mark Douglas',
    summary: 'thinking in probabilities, and why any one trade is unknown.',
  ),
  ReadingCard(
    id: 'disciplined',
    title: 'The Disciplined Trader',
    author: 'Mark Douglas',
    summary: 'where impulsive habits come from, and how rules replace them.',
  ),
  ReadingCard(
    id: 'daily-coach',
    title: 'The Daily Trading Coach',
    author: 'Brett N. Steenbarger',
    summary: 'short lessons for being your own coach.',
  ),
  ReadingCard(
    id: 'enhancing',
    title: 'Enhancing Trader Performance',
    author: 'Brett N. Steenbarger',
    summary: 'building skill through practice and review.',
  ),
];

/// Day index for seeding: the same all day, local calendar.
int _dayIndex(DateTime now) => DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;

/// The affirmation of the day: seeded by the local date, so it changes once a day.
Affirmation affirmationOfDay(DateTime now) => kAffirmations[_dayIndex(now) % kAffirmations.length];

/// Where the prompt cards start today (seeded by date, like the affirmation).
int promptStartOfDay(DateTime now) => (_dayIndex(now) * 7) % kMindPrompts.length;

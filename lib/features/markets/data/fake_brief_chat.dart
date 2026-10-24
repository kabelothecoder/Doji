import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/data/fake_coach.dart';
import '../../onboarding/domain/user_zone.dart';
import '../domain/market_format.dart';
import '../domain/news.dart';
import '../domain/pair_brief.dart';
import '../domain/strategy_reading.dart';

/// Answers questions about one brief from the brief itself: why something is
/// waiting, the risk note, what the entry needs. Anything else goes to the
/// fake coach's rules (crisis first, no market calls, back to the plan).
class FakeBriefChat implements BriefChat {
  const FakeBriefChat({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  static final _why = RegExp(r'\bwhy\b|\bwaiting\b');
  static final _entry = RegExp(r'\bretest\b|what counts|\bmy entry\b|\bentry need');
  static final _risk = RegExp(r'\brisk\b|\bnews\b');

  @override
  Future<String> reply(PairBrief brief, BriefRequest request, List<BriefTurn> history, String message) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return replyFor(brief, request, message, turn: history.where((t) => !t.fromYou).length);
  }

  static String replyFor(PairBrief brief, BriefRequest request, String message, {int turn = 0}) {
    final t = message.toLowerCase();
    final intent = FakeCoach.intentOf(message);
    // The coach's hard rules come before anything about the brief.
    if (intent == CoachIntent.crisis || intent == CoachIntent.call) {
      return FakeCoach.replyFor(intent, request.coach, turn: turn);
    }
    if (_entry.hasMatch(t)) return _entryAnswer(request);
    if (_why.hasMatch(t)) return _whyWaiting(brief);
    if (_risk.hasMatch(t)) return _riskAnswer(brief, request);
    if (intent != CoachIntent.other) return FakeCoach.replyFor(intent, request.coach, turn: turn);
    return 'i can walk you through this brief: the conditions, the risk note or your entry. which part?';
  }

  static String _whyWaiting(PairBrief brief) {
    final waiting = brief.waiting.map((c) => c.text.toLowerCase()).toList();
    if (waiting.isEmpty) {
      return 'nothing on your list is waiting right now: ${brief.metCount} of ${brief.conditions.length} are met.';
    }
    final which = waiting.length == 1 ? 'one condition is' : '${waiting.length} conditions are';
    return '$which still waiting: ${waiting.join('; ')}. doji marks a condition met only when your rule is met, '
        'not when it looks close.';
  }

  static String _entryAnswer(BriefRequest request) {
    final s = StrategyReading.of(request.profile.strategy?.parsed);
    final tf = s.timeframe.label;
    if (s.entry == null) {
      return "you haven't described your entry yet. once you do, doji measures every brief against it.";
    }
    if (s.retest) {
      return 'by your plan, the entry is: ${s.entry}. on $tf, that means a candle comes back to the broken level '
          "and closes beyond it. a touch on its own isn't a retest.";
    }
    return "by your plan, the entry is: ${s.entry}, on $tf. doji can't read that from the chart yet, so check it "
        'on your own chart first.';
  }

  static String _riskAnswer(PairBrief brief, BriefRequest request) {
    final c = request.coach;
    final risk = c.riskPerTradePct;
    final size = risk == null ? 'the size your plan sets' : '${_n(risk)}% a trade';
    if (brief.dayDone) {
      return "your rules decide when the day ends, not the chart. stopping here keeps tomorrow's account "
          'intact. the next brief starts fresh.';
    }
    final news = brief.nextNews;
    if (news != null) {
      final zone = userZoneFromProfile(request.profile);
      return 'big releases can move price fast and widen spreads, so your rule keeps you out $kNewsBufferMinutes '
          'min either side of ${clockDayTime(zone, news.at, now: request.now)}. outside that window, risk stays '
          'at $size, the same as any trade.';
    }
    return 'your risk is $size. the note is a reminder that a setup that looks good gets the same size as any '
        'other.';
  }

  static String _n(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }
}

/// The chat behind "ask about this brief". Tests override it with zero latency.
final briefChatProvider = Provider<BriefChat>((ref) => const FakeBriefChat());

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_doji.dart';
import '../domain/strategy_parser.dart';

/// Keyword-matching stand-in for the LLM parser. Offline, deterministic,
/// good enough to demo the flow and to keep onboarding local-first.
///
/// TODO(next-slice): replace with `SupabaseStrategyParser`, which POSTs
/// `{ description }` to the `parse-strategy` Edge Function and maps the JSON
/// response onto [ParsedStrategy]. Keep this class as the offline fallback.
class MockStrategyParser implements StrategyParser {
  const MockStrategyParser({this.latency = const Duration(milliseconds: 900)});

  /// Simulated model latency, so the "> reading your strategy_" state is real.
  final Duration latency;

  static final _timeframe = RegExp(r'\b(m1|m5|m15|m30|h1|h4|d1|w1)\b', caseSensitive: false);
  static final _minutes = RegExp(r'\b(1|5|15|30)\s*(?:m|min|mins|minute|minutes)\b', caseSensitive: false);
  static final _hours = RegExp(r'\b(1|4)\s*(?:h|hr|hour|hours)\b', caseSensitive: false);
  static final _rMultiple = RegExp(r'\b(\d+(?:\.\d+)?)\s*r\b', caseSensitive: false);
  static final _rrRatio = RegExp(r'\b1\s*:\s*(\d+(?:\.\d+)?)\b');
  static final _stop = RegExp(
    r'\b(?:stop(?:\s*loss)?|sl)\s+(?:is\s+|goes\s+|at\s+)?(under|below|above|beyond|behind|at)\s+([^,.;]+)',
    caseSensitive: false,
  );
  static final _target = RegExp(
    r'\b(?:target|tp|take profit)\s+(?:is\s+|at\s+)?([^,.;]+)',
    caseSensitive: false,
  );

  @override
  Future<ParsedStrategy> parse(String description) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return parseSync(description);
  }

  ParsedStrategy parseSync(String description) {
    final text = description.trim();
    final t = text.toLowerCase();
    if (t.isEmpty) return const ParsedStrategy();

    final asianRange =
        t.contains('asian range') || t.contains('asia range') || t.contains('asian session range');

    return ParsedStrategy(
      setup: _setup(t, asianRange, text),
      timeframe: _tf(t),
      entry: _entry(t),
      stop: _stopText(t, asianRange),
      target: _targetText(t),
    );
  }

  String? _setup(String t, bool asianRange, String original) {
    final breakout = t.contains('breakout') || t.contains('break out') || RegExp(r'\bbreak\b').hasMatch(t);
    if (t.contains('london') && breakout && asianRange) return 'london breakout of the asian range';
    if (t.contains('new york') && breakout) return 'new york breakout';
    if (['order block', 'fvg', 'fair value gap', 'liquidity', 'smc', 'ict', 'bos', 'choch'].any(t.contains)) {
      return 'liquidity sweep into an order block (smc/ict)';
    }
    if (t.contains('pullback') || t.contains('retrace') || t.contains('pull back')) {
      return 'pullback in an established trend';
    }
    if (t.contains('support') || t.contains('resistance') || t.contains('s&r') || t.contains('s/r')) {
      return 'reaction at a marked support or resistance level';
    }
    if (breakout) return 'breakout of a consolidation range';
    // Fall back to the first clause of their own words.
    final first = original.split(RegExp(r'[.,;\n]')).first.trim();
    return first.isEmpty ? null : first.toLowerCase();
  }

  String? _tf(String t) {
    final m = _timeframe.firstMatch(t);
    if (m != null) return m.group(1)!.toUpperCase();
    final mins = _minutes.firstMatch(t);
    if (mins != null) return 'M${mins.group(1)}';
    final hrs = _hours.firstMatch(t);
    if (hrs != null) return 'H${hrs.group(1)}';
    if (t.contains('daily')) return 'D1';
    return null;
  }

  String? _entry(String t) {
    if (t.contains('retest')) return 'retest of the broken level, candle closes beyond';
    if (t.contains('engulf')) return 'engulfing candle at the level';
    if (t.contains('pin bar') || t.contains('rejection')) return 'rejection candle at the level';
    if (t.contains('structure shift') || t.contains('mss') || t.contains('choch')) {
      return 'market structure shift';
    }
    if (t.contains('close above') || t.contains('close below') || t.contains('closes beyond')) {
      return 'candle closes beyond the level';
    }
    return null;
  }

  String? _stopText(String t, bool asianRange) {
    final m = _stop.firstMatch(t);
    if (m == null) return null;
    var where = m.group(2)!.trim();
    // "under the range" after describing the asian range means that range.
    if (asianRange && RegExp(r'^the range\b').hasMatch(where)) {
      where = where.replaceFirst('the range', 'the asian range');
    }
    return '${m.group(1)} $where';
  }

  String? _targetText(String t) {
    final r = _rMultiple.firstMatch(t);
    if (r != null) return '${_trim(r.group(1)!)}R';
    final rr = _rrRatio.firstMatch(t);
    if (rr != null) return '${_trim(rr.group(1)!)}R';
    final m = _target.firstMatch(t);
    return m?.group(1)?.trim();
  }

  static String _trim(String n) => n.endsWith('.0') ? n.substring(0, n.length - 2) : n;
}

/// Swap for the Supabase implementation in the next slice.
final strategyParserProvider = Provider<StrategyParser>((ref) => const MockStrategyParser());

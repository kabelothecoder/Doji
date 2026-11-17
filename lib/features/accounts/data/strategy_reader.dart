import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_functions.dart';
import '../../../core/copy_rules.dart';
import '../../onboarding/data/mock_strategy_parser.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/strategy_parser.dart';
import '../domain/condition_eval.dart';
import '../domain/trading_account.dart';

/// What doji read from the trader's words: the parsed fields and the
/// conditions it proposes (measurable kinds, everything else manual).
class StrategyProposal {
  const StrategyProposal({required this.parsed, required this.conditions});

  final ParsedStrategy parsed;
  final List<StrategyCondition> conditions;
}

/// Reads a strategy in the trader's own words. Never a fixed indicator menu
/// (owner decision 2026-11-02): rules doji can't measure stay manual.
abstract interface class StrategyReader {
  Future<StrategyProposal> propose(String words, {List<String> sessions = const []});
}

/// On the device: the keyword parser and today's default conditions.
class FakeStrategyReader implements StrategyReader {
  const FakeStrategyReader([this.parser = const MockStrategyParser(latency: Duration.zero)]);

  final MockStrategyParser parser;

  @override
  Future<StrategyProposal> propose(String words, {List<String> sessions = const []}) async {
    final parsed = parser.parseSync(words);
    return StrategyProposal(parsed: parsed, conditions: defaultConditions(parsed));
  }
}

/// Gemini through `ai-strategy`. It is also the [StrategyParser] onboarding
/// and the editor's save use. Any failure falls back to [fallback].
class SupabaseStrategyReader implements StrategyReader, StrategyParser {
  const SupabaseStrategyReader(this._ai, {this.fallback = const FakeStrategyReader()});

  final AiFunctions _ai;
  final FakeStrategyReader fallback;

  @override
  Future<ParsedStrategy> parse(String description) async => (await propose(description)).parsed;

  @override
  Future<StrategyProposal> propose(String words, {List<String> sessions = const []}) async {
    try {
      final res = await _ai.call('ai-strategy', {'words': words, 'sessions': sessions});
      final p = res['parsed'];
      final list = res['conditions'];
      if (p is Map && list is List) return fromJson(p, list);
    } on AiFailure {
      // fall through
    }
    return fallback.propose(words, sessions: sessions);
  }

  /// The function's reply, checked again here: unknown kinds and anything that
  /// breaks the copy rules never reach the editor.
  static StrategyProposal fromJson(Map<dynamic, dynamic> p, List<dynamic> list) {
    String? field(Object? v) => v is String && v.trim().isNotEmpty && !breaksCopyRules(v) ? v.trim() : null;
    final conditions = <StrategyCondition>[];
    for (final c in list.whereType<Map<dynamic, dynamic>>()) {
      try {
        final cond = StrategyCondition.fromJson(Map<String, dynamic>.from(c));
        if (cond.kind == ConditionKind.manual && field(cond.text) == null) continue;
        conditions.add(cond);
      } on Object {
        continue; // an unknown kind: dropped, never guessed
      }
    }
    return StrategyProposal(
      parsed: ParsedStrategy(
        setup: field(p['setup']),
        timeframe: field(p['timeframe']),
        entry: field(p['entry']),
        stop: field(p['stop']),
        target: field(p['target']),
      ),
      conditions: conditions,
    );
  }
}

/// The editor's "read my words". Without Supabase: the on-device reader.
final strategyReaderProvider = Provider<StrategyReader>((ref) {
  final ai = ref.watch(aiFunctionsProvider);
  return ai == null ? const FakeStrategyReader() : SupabaseStrategyReader(ai);
});

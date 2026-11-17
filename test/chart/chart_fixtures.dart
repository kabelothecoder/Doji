import 'dart:convert';

import 'package:doji_app/features/chart/data/chart_note_repository.dart';
import 'package:doji_app/features/chart/domain/chart_note.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';

import '../helpers/app_harness.dart';
import '../helpers/sample_profile.dart';

const kStrategyWords =
    'london breakout of the asian range. i take order blocks only after a london sweep. '
    'entry on the m15 retest, candle closes beyond the level.';

/// Sam on a 10 000 USD account, EURUSD watched, risk 1% · 3 trades · 2%.
Map<String, Object> chartSeed({Map<String, Object> extra = const {}, double? startingSize = 10000}) => {
  ...seedProfile(
    profile: profileWith(
      name: 'sam',
      instruments: const ['EURUSD', 'XAUUSD'],
      sessions: const ['london'],
      timeZone: 'Africa/Johannesburg',
      utcOffsetMinutes: 120,
      startingSize: startingSize,
      strategy: const StrategyProfile(
        rawText: kStrategyWords,
        parsed: ParsedStrategy(
          setup: 'london breakout of the asian range',
          timeframe: 'M15',
          entry: 'retest of the broken level, candle closes beyond',
        ),
      ),
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
      pledgedAt: DateTime.utc(2026, 7, 1),
      completedAt: DateTime.utc(2026, 7, 1),
    ),
  ),
  ...extra,
};

ChartNote noteFor(Drawing d, {DateTime? at, String? reason, String? reply, String? tradeId}) {
  final t = at ?? DateTime.utc(2026, 7, 15, 11);
  return ChartNote(
    id: d.id,
    accountId: kFirstAccountId,
    symbol: 'EURUSD',
    timeframe: Timeframe.m15,
    createdAt: t,
    updatedAt: t,
    drawing: d,
    reason: reason,
    copilot: [
      if (reason != null) CopilotTurn(fromYou: true, text: reason, at: t),
      if (reply != null) CopilotTurn(fromYou: false, text: reply, at: t),
    ],
    tradeId: tradeId,
  );
}

Map<String, Object> seedNotes(List<ChartNote> notes) => {
  PrefsChartNoteRepository.key: jsonEncode({
    'version': PrefsChartNoteRepository.version,
    'notes': [for (final n in notes) n.toJson()],
  }),
};

// Goldens for journal insights and the imported trade (Doji Trade Journal Phone › imported,
// insights, insight; Doji Insight Card) on iPhone 390 × 844.
//
//   flutter test test/goldens --update-goldens   # after an intended change
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/data/trade_import.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/insights_fixtures.dart';
import '../journal/journal_fixtures.dart';

class _Import implements TradeImport {
  _Import(this.trades);

  final List<Trade> trades;

  @override
  Future<List<Trade>> closedTrades(TradingAccount account) async => trades;
}

void main() {
  for (final (route, name) in [
    (Routes.journal, 'imported'),
    (Routes.insights, 'feed'),
    (Routes.insight('time'), 'detail'),
  ]) {
    testWidgets('insights · $name phone', (tester) async {
      await withClock(summerDay, () async {
        final local = summerDay.now().toLocal();
        final h = await AppHarness.pump(
          tester,
          at: route,
          seed: {...seedProfile(), ...seedJournal(insightTrades(local))},
          overrides: [
            tradeImportProvider.overrideWithValue(_Import([importedTrade(local)])),
          ],
        );
        await h.wait(1500);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('insights_${name}_phone.png'));
      });
    }, variant: ios);
  }
}

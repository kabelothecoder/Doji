// Journal insights and the imported banner at 1x and 2x text.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/data/trade_import.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import 'insights_fixtures.dart';
import 'journal_fixtures.dart';

class _Import implements TradeImport {
  _Import(this.trades);

  final List<Trade> trades;

  @override
  Future<List<Trade>> closedTrades(TradingAccount account) async => trades;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final route in [Routes.journal, Routes.insights, Routes.insight('time')]) {
      testWidgets('$route at ${scale}x text', (tester) async {
        await withClock(summerDay, () async {
          final local = summerDay.now().toLocal();
          final h = await AppHarness.pump(
            tester,
            at: route,
            seed: {...seedProfile(), ...seedJournal(insightTrades(local))},
            overrides: [
              tradeImportProvider.overrideWithValue(_Import([importedTrade(local)])),
            ],
            textScale: scale,
          );
          await h.wait(1500);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (route == Routes.insights) {
            expect(find.bySemanticsLabel(RegExp(r'trades\. \d+ above the line')), findsWidgets);
          }
        });
      }, variant: ios);
    }
  }
}

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/domain/plan_kept.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_fixtures.dart';

void main() {
  Trade t(String id, int? v, {PlanFollowed? plan}) {
    final base = sampleTrade(id: id, pnl: 50, accountId: 'a').withStrategyVersion(v);
    return plan == null ? base : base.withReview(TradeReview(setup: 's', plan: plan), DateTime.utc(2026));
  }

  test('strategyVersion survives json', () {
    final back = Trade.fromJson(t('x', 3).toJson())!;
    expect(back.strategyVersion, 3);
    expect(Trade.fromJson(t('y', null).toJson())!.strategyVersion, isNull);
  });

  test('plan kept per version, newest first; partly is not kept', () {
    final rows = PlanKept.byVersion([
      t('1', 1, plan: PlanFollowed.yes),
      t('2', 2, plan: PlanFollowed.yes),
      t('3', 2, plan: PlanFollowed.partly),
      t('4', 2),
      t('5', null, plan: PlanFollowed.no),
      sampleTrade(id: 'other', pnl: 1, accountId: 'b').withStrategyVersion(2),
    ], 'a');
    expect([for (final r in rows) r.version], [2, 1, null]);
    expect(rows.first.line, 'version 2 · plan kept on 1 of 2 reviewed trades');
    expect(rows.first.trades, 3);
    expect(rows.last.line, 'before versions · plan kept on 0 of 1 reviewed trades');
    for (final r in rows) {
      expect(breaksCopyRules(r.line), isFalse);
    }
  });

  test('new words make a new version; the same or first words do not', () {
    const old = TradingAccount(
      id: 'a',
      name: 'a',
      kind: AccountKind.personal,
      strategy: StrategyProfile(rawText: 'london break'),
    );
    final now = DateTime.utc(2026, 11, 15);
    final changed = versionOnNewWords(
      old,
      old.copyWith(strategy: const StrategyProfile(rawText: 'ny open')),
      now: now,
    );
    expect(changed.strategyVersion, 2);
    expect(changed.strategyVersions.single.strategy?.rawText, 'london break');
    expect(versionOnNewWords(old, old, now: now).strategyVersion, 1);
    const blank = TradingAccount(id: 'a', name: 'a', kind: AccountKind.personal);
    expect(versionOnNewWords(blank, old, now: now).strategyVersion, 1);
  });
}

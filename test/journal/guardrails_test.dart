import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/domain/guardrails.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/markets/domain/news.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final open = DateTime(2026, 7, 15, 9, 0); // local
  Trade trade({double? stop = 1995, double? risk = 100}) => Trade(
    id: 't',
    symbol: 'XAUUSD',
    direction: TradeDirection.long,
    openedAt: open.toUtc(),
    closedAt: open.add(const Duration(minutes: 30)).toUtc(),
    entry: 2000,
    exit: 2005,
    size: 1,
    pnl: 50,
    stop: stop,
    riskMoney: risk,
  );
  TradingAccount account(TradingRules rules) =>
      TradingAccount(id: 'a', name: 'a', kind: AccountKind.personal, startingSize: 10000, rules: rules);

  test('minutesOf reads HH:mm only', () {
    expect(minutesOf('09:35'), 575);
    expect(minutesOf('9:05'), 545);
    expect(minutesOf('25:00'), isNull);
    expect(minutesOf('soon'), isNull);
    expect(minutesOf(null), isNull);
  });

  test('a clean trade has no flags', () {
    expect(guardrailFlags(trade(), account: account(const TradingRules(riskPerTrade: 1))), isEmpty);
  });

  test('no stop', () {
    expect(guardrailFlags(trade(stop: null, risk: null)), ['no stop recorded.']);
  });

  test('risk above plan, with a 10% tolerance', () {
    final a = account(const TradingRules(riskPerTrade: 1));
    expect(guardrailFlags(trade(risk: 105), account: a), isEmpty);
    expect(guardrailFlags(trade(risk: 250), account: a), ['risked 2.5% of the account; your plan is 1%.']);
    // Without a starting size there is nothing to measure against.
    expect(guardrailFlags(trade(risk: 250), account: a.copyWith(startingSize: null)), isEmpty);
  });

  test('opened inside the news window', () {
    final near = NewsEvent(
      at: open.add(const Duration(minutes: 20)).toUtc(),
      currency: 'USD',
      title: 'us cpi',
    );
    final far = NewsEvent(at: open.add(const Duration(hours: 2)).toUtc(), currency: 'USD', title: 'fomc');
    expect(guardrailFlags(trade(), news: [near, far]), ['opened at 09:00, 20 min from us cpi.']);
  });

  test('trading window', () {
    const rules = TradingRules(noTradesBefore: '09:35', noTradesAfter: '11:30');
    expect(outsideWindow(rules, open), 'before your 09:35 start');
    expect(outsideWindow(rules, DateTime(2026, 7, 15, 10)), isNull);
    expect(outsideWindow(rules, DateTime(2026, 7, 15, 11, 30)), 'after your 11:30 finish');
    expect(outsideWindow(const TradingRules(), open), isNull);
    expect(guardrailFlags(trade(), account: account(rules)), ['opened at 09:00, before your 09:35 start.']);
  });

  test('flags keep the copy rules', () {
    final all = guardrailFlags(
      trade(stop: null, risk: 300),
      account: account(const TradingRules(riskPerTrade: 1, noTradesAfter: '08:00')),
      news: [NewsEvent(at: open.toUtc(), currency: 'USD', title: 'us cpi')],
    );
    expect(all, hasLength(4));
    for (final f in all) {
      expect(breaksCopyRules(f), isFalse, reason: f);
    }
  });
}

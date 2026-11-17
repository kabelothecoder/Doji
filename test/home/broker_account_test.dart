import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/home/domain/broker_account.dart';
import 'package:doji_app/features/home/domain/home_models.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 15, 10);

  ProfileDoji profile(PropRules prop) => ProfileDoji(
    accounts: [
      TradingAccount(
        id: 'acc_1',
        name: 'challenge',
        startingSize: 10000,
        prop: prop,
        brokerLink: const BrokerLink(server: 'Broker-Server', login: 123),
      ),
    ],
  );

  BrokerReading reading({
    required double balance,
    required double equity,
    BrokerReading? prev,
    DateTime? at,
  }) => BrokerReading.track(
    prev,
    balance: balance,
    equity: equity,
    currency: 'USD',
    asOf: at ?? now,
    day: '2026-07-15',
    startingSize: 10000,
  );

  group('tracking', () {
    test('highs only rise, from at least the starting size; the day starts at the first balance', () {
      var r = reading(balance: 9900, equity: 9850);
      expect(r.peakBalance, 10000);
      expect(r.peakEquity, 10000);
      expect(r.dayStartBalance, 9900);
      r = reading(balance: 10400, equity: 10600, prev: r);
      expect(r.peakEquity, 10600);
      r = reading(balance: 10200, equity: 10100, prev: r);
      expect(r.peakBalance, 10400);
      expect(r.peakEquity, 10600);
      expect(r.dayStartBalance, 9900);
      final tomorrow = BrokerReading.track(
        r,
        balance: 10200,
        equity: 10200,
        currency: 'USD',
        asOf: now,
        day: '2026-07-16',
        startingSize: 10000,
      );
      expect(tomorrow.dayStartBalance, 10200);
      expect(BrokerReading.fromJson(tomorrow.toJson())!.peakEquity, 10600);
    });
  });

  group('Home uses broker equity', () {
    const trailing = PropRules(
      maxDrawdownPct: 10,
      drawdownType: DrawdownType.trailing,
      trailingBasis: TrailingBasis.equity,
    );

    test('trailing equity drawdown is measured from the broker high, loss % from the day start', () {
      var r = reading(balance: 10000, equity: 10500);
      r = reading(balance: 10000, equity: 9800, prev: r); // high 10500, now 9800: 7% of 10000 used
      final snap = HomeSnapshot.fromJournal(profile(trailing), trades: const [], now: now, broker: r);
      final dd = snap.usage.firstWhere((u) => u.label.startsWith('prop'));
      expect(dd.used, 7);
      expect(dd.label, 'prop trailing equity drawdown');
      final loss = snap.usage.firstWhere((u) => u.label == 'daily loss');
      expect(loss.used, 2); // 10000 → 9800 equity
      expect(snap.accountNote, startsWith('broker figures · as of '));
    });

    test('static drawdown reads broker equity against the starting size', () {
      final r = reading(balance: 9700, equity: 9600);
      final snap = HomeSnapshot.fromJournal(
        profile(const PropRules(maxDrawdownPct: 8)),
        trades: const [],
        now: now,
        broker: r,
      );
      expect(snap.usage.firstWhere((u) => u.label.startsWith('prop')).used, 4);
    });

    test('a stale figure is never shown as current: the journal is used and the note says so', () {
      final old = reading(balance: 10000, equity: 9000, at: now.subtract(const Duration(minutes: 5)));
      final snap = HomeSnapshot.fromJournal(profile(trailing), trades: const [], now: now, broker: old);
      expect(snap.usage.firstWhere((u) => u.label.startsWith('prop')).used, 0); // journal: no trades
      expect(snap.usage.firstWhere((u) => u.label == 'daily loss').used, 0);
      expect(snap.accountNote, contains('too old to use'));
    });

    test('no link, no note', () {
      final snap = HomeSnapshot.fromJournal(profile(trailing), trades: const [], now: now);
      expect(snap.accountNote, isNull);
    });
  });
}

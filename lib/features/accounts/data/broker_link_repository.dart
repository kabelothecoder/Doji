import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/domain/broker_account.dart';
import '../../markets/data/mt5_api.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/trading_account.dart';

/// Links a [TradingAccount] to the trader's MT5 account and reads its balance
/// and equity, all through the `mt5` edge function. On the device: only the
/// link's server and login (in profile.doji) and the last reading with its
/// highs (shared_preferences `doji.broker.v1`, per account id).
class BrokerLinkRepository {
  const BrokerLinkRepository(this._api, this._prefs);

  final Mt5Api? _api;
  final SharedPreferences _prefs;

  static const key = 'doji.broker.v1';

  /// False without Supabase (fully local) or signed out.
  bool get available => _api != null;

  Mt5Api get _requireApi => _api ?? (throw const Mt5Failure('sign in to link a broker.'));

  /// Connects the MT5 account server-side. The password goes to the function
  /// once and is kept in Supabase Vault; it is never stored here.
  Future<BrokerLink> link(
    String accountId, {
    required String server,
    required int login,
    required String password,
  }) async {
    await _requireApi.call('link', accountId, {'server': server, 'login': login, 'password': password});
    await _forget(accountId);
    return BrokerLink(server: server, login: login);
  }

  Future<void> unlink(String accountId) async {
    await _requireApi.call('unlink', accountId);
    await _forget(accountId);
  }

  Map<String, Object?> _all() {
    try {
      final raw = _prefs.getString(key);
      return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  Future<void> _forget(String accountId) => _prefs.setString(key, jsonEncode(_all()..remove(accountId)));

  /// The last reading kept for [accountId] (may be stale).
  BrokerReading? last(String accountId) => BrokerReading.fromJson(_all()[accountId]);

  /// Asks the broker now and folds the answer into the stored highs. When the
  /// broker can't be reached, the last reading comes back (old, and Home then
  /// says so).
  Future<BrokerReading?> refresh(TradingAccount account) async {
    final previous = last(account.id);
    final api = _api;
    if (api == null || account.brokerLink == null) return previous;
    try {
      final d = await api.call('account', account.id);
      final balance = (d['balance'] as num?)?.toDouble();
      final equity = (d['equity'] as num?)?.toDouble();
      if (balance == null || equity == null) return previous;
      final asOf = DateTime.fromMillisecondsSinceEpoch((d['asOf'] as num?)?.toInt() ?? 0, isUtc: true);
      final next = BrokerReading.track(
        previous,
        balance: balance,
        equity: equity,
        currency: d['currency'] as String? ?? account.accountCurrency,
        asOf: asOf,
        day: localDay(clock.now()),
        startingSize: account.startingSize ?? balance,
      );
      await _prefs.setString(key, jsonEncode(_all()..[account.id] = next.toJson()));
      return next;
    } on Object {
      return previous;
    }
  }

  /// Sign out and delete.
  Future<void> clear() => _prefs.remove(key);
}

final brokerLinkRepositoryProvider = Provider<BrokerLinkRepository>(
  (ref) => BrokerLinkRepository(ref.watch(mt5ApiProvider), ref.watch(sharedPreferencesProvider)),
);

/// How often Home asks the broker while it is on screen.
const Duration kBrokerPoll = Duration(seconds: 60);

/// The active account's broker reading, refreshed every [kBrokerPoll] while
/// watched. Null when the account has no link.
final brokerReadingProvider = FutureProvider.autoDispose<BrokerReading?>((ref) async {
  final account = ref.watch(onboardingRepositoryProvider).loadProfile()?.activeAccount;
  if (account == null || account.brokerLink == null) return null;
  final repo = ref.watch(brokerLinkRepositoryProvider);
  final timer = Timer(kBrokerPoll, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return repo.refresh(account);
});

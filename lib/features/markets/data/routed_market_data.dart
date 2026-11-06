import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/candle.dart';
import '../domain/instrument.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';
import 'deriv_market_data.dart';
import 'fake_market_data.dart';
import 'mt5_api.dart';
import 'mt5_market_data.dart';

/// The one [MarketData] the app reads. Per instrument:
/// - Deriv synthetics (`R_*`, `BOOM*`, `CRASH*`) → [deriv];
/// - forex, metals, indices and oil → the active account's MT5 link
///   ([broker], null while it has none);
/// - everything else (crypto, custom symbols, no link) → [sample].
class RoutedMarketData implements MarketData {
  const RoutedMarketData({required this.sample, this.deriv, this.broker});

  final MarketData sample;
  final MarketData? deriv;

  /// Read per call: the active account (and so its link) can change.
  final MarketData? Function()? broker;

  /// Which feed answers for [symbol].
  MarketData feedFor(String symbol) {
    final i = instrumentBySymbol(symbol);
    if (i == null) return sample;
    if (i.assetClass == AssetClass.synthetic) return deriv ?? sample;
    final mt5 = broker?.call();
    final viaBroker = switch (i.group) {
      InstrumentGroup.forex ||
      InstrumentGroup.metals ||
      InstrumentGroup.indices ||
      InstrumentGroup.oil => true,
      _ => false,
    };
    return viaBroker && mt5 != null ? mt5 : sample;
  }

  @override
  FeedSource sourceOf(String symbol) => feedFor(symbol).sourceOf(symbol);

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) => feedFor(symbol).quote(symbol, now: now);

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) =>
      feedFor(symbol).candles(symbol, tf, now: now, count: count);

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) => feedFor(symbol).candlesBetween(symbol, tf, from: from, to: to);
}

/// One Deriv socket for the app's life. Opens on the first synthetic price.
final derivMarketDataProvider = Provider<DerivMarketData>((ref) {
  final feed = DerivMarketData(connect: derivConnector(appId: ref.watch(envProvider).derivAppId));
  ref.onDispose(feed.dispose);
  return feed;
});

/// The feed 1b, the brief and the watchlist read. Tests override it with a
/// zero-latency [FakeMarketData].
final marketDataProvider = Provider<MarketData>((ref) {
  final api = ref.watch(mt5ApiProvider);
  final repo = ref.watch(onboardingRepositoryProvider);
  return RoutedMarketData(
    sample: const FakeMarketData(),
    deriv: ref.watch(derivMarketDataProvider),
    broker: api == null
        ? null
        : () {
            final account = repo.loadProfile()?.activeAccount;
            final link = account?.brokerLink;
            if (account == null || link == null) return null;
            return Mt5MarketData(api: api, accountRef: account.id, server: link.server);
          },
  );
});

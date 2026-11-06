import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/rate_source.dart';
import 'mt5_api.dart';

/// One cached rate: the broker's mid and when doji fetched it.
class CachedRate {
  const CachedRate(this.mid, this.fetchedAt);

  final double mid;
  final DateTime fetchedAt;
}

/// Live exchange rates from the trader's MT5 account (the `mt5` edge
/// function's `rates`: the broker's own FX quotes), cached with the time they
/// were fetched. [rate] answers null once a rate is older than [maxAge], so
/// `RiskSizing` and `TradeMath` refuse to size on it instead of guessing.
///
/// Without a broker link (or Supabase) only same-currency rates exist: the
/// journal then asks the trader for the broker's figure.
class LiveRateSource implements RateSource {
  LiveRateSource({required this.api, required this.accountRef, this.maxAge = const Duration(minutes: 5)});

  final Mt5Api? api;

  /// A linked account to ask; read per call because links change.
  final String? Function() accountRef;
  final Duration maxAge;

  final _cache = <String, CachedRate>{};

  static String _key(String from, String to) => '${from.toUpperCase()}${to.toUpperCase()}';

  CachedRate? _fresh(String pair) {
    final c = _cache[pair];
    if (c == null || clock.now().difference(c.fetchedAt) > maxAge) return null;
    return c;
  }

  /// The cached rate for [from] → [to] with its time, fresh or not (to show "as of").
  CachedRate? cached(String from, String to) => _cache[_key(from, to)];

  @override
  double? rate(String from, String to) {
    final f = from.toUpperCase(), t = to.toUpperCase();
    if (f == t) return 1;
    final direct = _fresh(_key(f, t));
    if (direct != null) return direct.mid;
    final inverse = _fresh(_key(t, f));
    if (inverse != null && inverse.mid > 0) return 1 / inverse.mid;
    // Through USD when the broker has no cross.
    if (f != 'USD' && t != 'USD') {
      final a = rate(f, 'USD'), b = rate('USD', t);
      if (a != null && b != null) return a * b;
    }
    return null;
  }

  @override
  Future<void> prepare(String from, String to) async {
    final f = from.toUpperCase(), t = to.toUpperCase();
    final ref = accountRef();
    if (f == t || api == null || ref == null || rate(f, t) != null) return;
    final pairs = {_key(f, t), _key(t, f), _key(f, 'USD'), _key('USD', f), _key(t, 'USD'), _key('USD', t)}
      ..removeWhere((p) => p.substring(0, 3) == p.substring(3));
    try {
      final d = await api!.call('rates', ref, {'pairs': pairs.toList()});
      final now = clock.now();
      final rates = d['rates'];
      if (rates is! Map) return;
      rates.forEach((pair, v) {
        if (pair is! String || v is! Map) return;
        final bid = (v['bid'] as num?)?.toDouble(), ask = (v['ask'] as num?)?.toDouble();
        if (bid == null || ask == null || bid <= 0 || ask <= 0) return;
        _cache[pair] = CachedRate((bid + ask) / 2, now);
      });
    } on Object {
      // Offline or refused: the pair stays unknown and sizing is refused.
    }
  }
}

/// The rates sizing and the journal use. Asks the active account if it is
/// linked, else the first linked account.
final rateSourceProvider = Provider<RateSource>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return LiveRateSource(
    api: ref.watch(mt5ApiProvider),
    accountRef: () {
      final p = repo.loadProfile();
      if (p == null) return null;
      final active = p.activeAccount;
      if (active?.brokerLink != null) return active!.id;
      for (final a in p.accounts) {
        if (a.brokerLink != null) return a.id;
      }
      return null;
    },
  );
});

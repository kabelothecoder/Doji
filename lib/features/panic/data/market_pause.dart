import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart';

const _key = 'doji.panic.v1.pausedUntil';

/// The panic flow's "pause doji's market views for 24 hours": until this
/// instant 1b shows no written brief. Device-only.
// TODO(backend): sync the pause with the account once sync exists.
class MarketPause extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    final until = raw == null ? null : DateTime.tryParse(raw);
    return until != null && until.isAfter(clock.now()) ? until : null;
  }

  Future<DateTime> start() async {
    final until = clock.now().add(const Duration(hours: 24));
    await ref.read(sharedPreferencesProvider).setString(_key, until.toUtc().toIso8601String());
    state = until;
    return until;
  }

  Future<void> stop() async {
    await ref.read(sharedPreferencesProvider).remove(_key);
    state = null;
  }
}

final marketPauseProvider = NotifierProvider<MarketPause, DateTime?>(MarketPause.new);

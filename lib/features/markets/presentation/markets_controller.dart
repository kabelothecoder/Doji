import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/doji_haptics.dart';
import '../../../core/widgets/widgets.dart';
import 'pair_detail_controller.dart';

/// The pair open in the wide layout's second pane. Null until one is picked:
/// opening a brief uses the free plan's one a day, so doji never opens one
/// on the trader's behalf.
class MarketsSelection extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String symbol) => state = symbol;
}

final marketsSelectionProvider = NotifierProvider<MarketsSelection, String?>(MarketsSelection.new);

/// Adds [symbol] to the watchlist, or removes it; removing the last one asks
/// first (1b's bookmark and search share this). Saves profile.doji at once.
Future<void> toggleWatchlist(BuildContext context, WidgetRef ref, String symbol) async {
  final list = ref.read(watchlistProvider);
  final watching = list.any((s) => s.toUpperCase() == symbol.toUpperCase());
  if (watching && list.length == 1) {
    final ok = await showDojiAlert(
      context,
      title: 'remove your last market?',
      message: 'your watchlist will be empty. home falls back to gold and euro until you add one.',
      destructiveLabel: 'remove',
    );
    if (!ok || !context.mounted) return;
  }
  await ref.read(watchlistProvider.notifier).toggle(symbol);
  unawaited(ref.read(hapticsProvider).light());
}

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/instrument.dart';
import '../../domain/instrument_catalog.dart';
import '../../domain/market_format.dart';
import '../../domain/market_status.dart';
import '../../domain/strategy_state.dart';
import '../pair_detail_controller.dart';
import 'strategy_state_badge.dart';

/// Design `WatchlistRow` (Doji Core Tabs › 01 watchlist): symbol, name,
/// session badge, the (sample) price and the strategy state. One 72pt target
/// that opens the pair. Price is neutral, never green or orange.
class WatchlistRow extends ConsumerWidget {
  const WatchlistRow({super.key, required this.symbol, required this.onTap, this.selected = false});

  final String symbol;
  final VoidCallback onTap;

  /// The pair open in the wide layout's second pane.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instrument = instrumentBySymbol(symbol);
    final name = displaySymbol(symbol);
    final quote = ref.watch(pairQuoteProvider(symbol)).value;
    final brief = ref.watch(pairBriefProvider(symbol));
    final state = brief.value == null ? null : StrategyState.of(brief.value!.conditions);
    final session = sessionBadgeText(MarketStatus.of(instrument, clock.now()));
    final open = session != 'closed';
    final price = quote == null ? '—' : formatPrice(quote.price, quote.decimals);

    final label = [
      name,
      '$session session',
      if (quote != null) 'sample price $price',
      switch (brief) {
        AsyncData() => 'strategy ${state!.label}',
        AsyncError() => 'strategy not measured',
        _ => 'measuring',
      },
    ].join(', ');

    return DojiPressable(
      onPressed: onTap,
      semanticLabel: label,
      selected: selected,
      borderRadius: BorderRadius.circular(DojiRadius.chip),
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 0, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? DojiColors.elevated1 : null,
            borderRadius: selected ? BorderRadius.circular(DojiRadius.chip) : null,
            border: selected ? null : const Border(top: BorderSide(color: DojiColors.elevated2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name, style: DojiType.data.copyWith(fontSize: 16)),
                        _SessionBadge(text: session, open: open),
                      ],
                    ),
                    if (instrument != null) ...[
                      const SizedBox(height: 4),
                      Text(instrumentSubtitle(instrument), style: DojiType.callout.copyWith(fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right-aligned value column (as drawn); wraps, not clips, at large text.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: DojiType.data.copyWith(fontSize: 15, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    switch (brief) {
                      AsyncData() => StrategyStateBadge(state: state!),
                      AsyncError() => Text('not measured', style: DojiType.hint),
                      _ => Text('measuring…', style: DojiType.hint),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The second line under a symbol: its name, plus the broker's own symbol
/// when the label hides it ('volatility 75 · R_75').
String instrumentSubtitle(Instrument instrument) =>
    instrument.label == null ? instrument.name : '${instrument.name} · ${instrument.symbol}';

/// The watchlist's session badge: the session an open market is in, '24/7',
/// 'open' between sessions, or 'closed'.
String sessionBadgeText(MarketStatus status) => switch (status) {
  AlwaysOpen() => '24/7',
  InSession(:final session) => session.label.toLowerCase(),
  OpenBetweenSessions() => 'open',
  MarketClosed() => 'closed',
};

/// Hairline chip; the dot is filled while open, hollow when closed (shape,
/// not only colour).
class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.text, required this.open});

  final String text;
  final bool open;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? DojiColors.textSecondary : null,
            border: Border.all(color: DojiColors.textSecondary),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: DojiType.hint.copyWith(fontSize: 11))),
      ],
    ),
  );
}

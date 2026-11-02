import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/instrument.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_format.dart';
import 'markets_controller.dart';
import 'pair_detail_controller.dart';
import 'widgets/watchlist_row.dart';

/// The search screen's tabs (Doji Core Tabs › 01 "search to add pairs"), plus synthetics
/// (owner decision 2026-10-24: Deriv's indices are in the catalogue).
enum SearchClass {
  all('all'),
  forex('forex'),
  metals('metals'),
  indices('indices'),
  crypto('crypto'),
  synthetics('synthetics');

  const SearchClass(this.label);
  final String label;

  bool includes(Instrument i) => switch (this) {
    all => true,
    forex => i.assetClass == AssetClass.forex,
    metals => i.group == InstrumentGroup.metals,
    indices => i.group == InstrumentGroup.indices,
    crypto => i.assetClass == AssetClass.crypto,
    synthetics => i.assetClass == AssetClass.synthetic,
  };
}

/// Design: Doji Markets Phone › search. Find a market by symbol, name or a
/// broker spelling, filter by class, and add or remove it: the watchlist
/// (profile.doji › instruments) saves at once.
class MarketSearchScreen extends ConsumerStatefulWidget {
  const MarketSearchScreen({super.key});

  @override
  ConsumerState<MarketSearchScreen> createState() => _MarketSearchScreenState();
}

class _MarketSearchScreenState extends ConsumerState<MarketSearchScreen> {
  final _query = TextEditingController();
  var _class = SearchClass.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _done() => context.canPop() ? context.pop() : context.go(Routes.markets);

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final watching = ref.watch(watchlistProvider).map((s) => s.toUpperCase()).toSet();
    final results = [
      for (final i in visibleInstruments)
        if (_class.includes(i) && instrumentMatches(i.symbol, _query.text)) i,
    ];

    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // The field, done and the tabs stay put; only the results scroll.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(margin, 12, margin, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DojiTextField(
                              controller: _query,
                              hint: 'search markets, e.g. gbp',
                              semanticLabel: 'search markets',
                              large: false,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DojiButton(
                            label: 'done',
                            variant: DojiButtonVariant.ghost,
                            size: DojiButtonSize.small,
                            expand: false,
                            onPressed: _done,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        container: true,
                        label: 'market type',
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final c in SearchClass.values) ...[
                                DojiChoiceChip(
                                  label: c.label,
                                  selected: c == _class,
                                  exclusive: true,
                                  style: DojiChoiceStyle.chip,
                                  onTap: () => setState(() => _class = c),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? ListView(
                          padding: EdgeInsets.fromLTRB(margin, 16, margin, 24),
                          children: [TerminalLine('nothing matches "${_query.text.trim()}".')],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(margin, 0, margin, 24),
                          itemCount: results.length,
                          itemBuilder: (context, i) => _ResultRow(
                            instrument: results[i],
                            watching: watching.contains(results[i].symbol),
                            onToggle: () => toggleWatchlist(context, ref, results[i].symbol),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Symbol and name, with a 44pt add / remove toggle. Added = white fill and
/// a check (shape, not only colour), as the design system's chips do.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.instrument, required this.watching, required this.onToggle});

  final Instrument instrument;
  final bool watching;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final name = displaySymbol(instrument.symbol);
    final size = DojiTokens.of(context).minTarget;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DojiColors.elevated2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: DojiType.data.copyWith(fontSize: 15, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 3),
                  Text(instrumentSubtitle(instrument), style: DojiType.callout.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          DojiPressable(
            onPressed: onToggle,
            semanticLabel: watching ? 'remove $name from watchlist' : 'add $name to watchlist',
            checked: watching,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: watching ? DojiColors.textPrimary : null,
                border: Border.all(color: watching ? DojiColors.textPrimary : DojiColors.separator),
              ),
              child: Icon(
                watching ? Icons.check_rounded : Icons.add_rounded,
                size: 20,
                color: watching ? DojiColors.bg : DojiColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

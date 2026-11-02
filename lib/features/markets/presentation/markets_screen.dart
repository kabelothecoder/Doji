import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/layout.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'markets_controller.dart';
import 'pair_detail_controller.dart';
import 'pair_detail_screen.dart';
import 'widgets/watchlist_row.dart';

/// The markets tab (design: Doji Core Tabs › 01 · watchlist, drawn in
/// Doji Markets Phone): what the brief is measured against, then the
/// watchlist with each instrument's session, sample price and strategy
/// state. A row opens 1b full screen on phones; on wide screens 1b is the
/// second pane (built from design-system parts: the handoff draws phones only).
///
/// Not built (owner decision 2026-10-24): "ask doji", the strategy manager
/// and its versions. Prices are SAMPLE data and say so.
class MarketsScreen extends ConsumerWidget {
  const MarketsScreen({super.key});

  /// The list's width beside the pane.
  static const listWidth = 380.0;

  /// Below this content width the wide layout keeps one pane and pushes 1b.
  static const twoPaneFrom = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWideLayout(context);
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            if (!wide || box.maxWidth < twoPaneFrom) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _Watchlist(onOpen: (s) => context.push(Routes.pairDetail(s))),
                ),
              );
            }
            final selected = ref.watch(marketsSelectionProvider);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: listWidth,
                  child: _Watchlist(
                    selected: selected,
                    onOpen: ref.read(marketsSelectionProvider.notifier).select,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: DojiColors.separator),
                Expanded(
                  child: selected == null
                      ? const _EmptyPane()
                      : PairDetailScreen(key: ValueKey(selected), symbol: selected, embedded: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Watchlist extends ConsumerWidget {
  const _Watchlist({required this.onOpen, this.selected});

  final ValueChanged<String> onOpen;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final symbols = ref.watch(watchlistProvider);
    final setup = ref.watch(marketsProfileProvider).strategy?.parsed?.setup?.trim();
    void search() => context.push(Routes.marketSearch);

    return ListView(
      padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('markets', style: DojiType.title)),
            ),
            _IconButton(icon: Icons.add_rounded, label: 'add a market', onPressed: search),
          ],
        ),
        const SizedBox(height: 16),
        _MeasuredAgainst(
          setup: setup == null || setup.isEmpty ? null : setup,
          onPressed: switch (ref.watch(marketsProfileProvider).activeAccount?.id) {
            final id? => () => context.push(Routes.accountEditor(id, strategy: true)),
            null => null,
          },
        ),
        const SizedBox(height: 16),
        if (symbols.isEmpty) ...[
          const TerminalLine('your watchlist is empty.', liveRegion: false),
          const SizedBox(height: 8),
          Text(
            'add the markets you trade and doji measures each against your strategy.',
            style: DojiType.callout,
          ),
          const SizedBox(height: 16),
          DojiButton(
            label: 'add a market',
            variant: DojiButtonVariant.outline,
            size: DojiButtonSize.regular,
            onPressed: search,
          ),
        ] else ...[
          ExcludeSemantics(
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  Text('WATCHLIST', style: DojiType.label.copyWith(fontSize: 11)),
                  const Spacer(),
                  Text('STRATEGY', style: DojiType.label.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
          for (final s in symbols) WatchlistRow(symbol: s, selected: s == selected, onTap: () => onOpen(s)),
        ],
        const SizedBox(height: 16),
        Text(
          'sample prices · not a live feed. states are measured against your strategy. not financial advice.',
          style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
        ),
      ],
    );
  }
}

/// "MEASURED AGAINST [setup]": what every state on the list is counted
/// against. Opens the active account's editor at its strategy.
class _MeasuredAgainst extends StatelessWidget {
  const _MeasuredAgainst({required this.setup, required this.onPressed});

  final String? setup;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onPressed,
    borderRadius: BorderRadius.circular(DojiRadius.card),
    semanticLabel: setup == null ? 'measured against your rules, no strategy yet' : 'measured against $setup',
    semanticHint: 'edit your strategy',
    child: ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: BorderRadius.circular(DojiRadius.card),
          border: Border.all(color: DojiColors.separator),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('MEASURED AGAINST', style: DojiType.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(
                    setup ?? 'your rules · no strategy yet',
                    style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DojiColors.textSecondary),
          ],
        ),
      ),
    ),
  );
}

/// The wide layout's second pane before a pair is picked.
class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: TerminalLine('pick a market to open its brief.', cursor: true, liveRegion: false),
    ),
  );
}

/// A bare 44pt icon button with its label.
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = DojiTokens.of(context).minTarget;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: DojiPressable(
        onPressed: onPressed,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: Icon(icon, size: 24, color: DojiColors.textSecondary)),
        ),
      ),
    );
  }
}

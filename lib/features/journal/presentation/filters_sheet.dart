import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/process_grade.dart';
import '../domain/trade_filter.dart';
import 'journal_controller.dart';

/// "filter trades": every group in one sheet, a live count on the button.
Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (_) => const FiltersSheet(),
  );
}

class FiltersSheet extends ConsumerWidget {
  const FiltersSheet({super.key});

  /// What each group offers: fixed lists, or what the journal actually holds.
  List<String> _options(FilterGroup g, List<String> symbols, List<String> setups, List<String> accounts) =>
      switch (g) {
        FilterGroup.account => accounts,
        FilterGroup.pair => symbols,
        FilterGroup.setup => setups,
        FilterGroup.session => [...kSessionNames, ...kOffHours],
        FilterGroup.weekday => kWeekdayNames,
        FilterGroup.tag => kMistakeTags,
        FilterGroup.grade => [for (final g in ProcessGrade.values) g.letter],
        FilterGroup.result => const ['win', 'loss'],
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(journalControllerProvider);
    final view = ref.watch(journalViewProvider);
    final filter = view.filter;
    final symbols = {for (final t in trades) t.symbol}.toList()..sort();
    final setups = {for (final t in trades) ?t.setup}.toList()..sort();
    final accounts = {for (final a in ref.watch(journalProfileProvider).accounts) a.id: a.name};
    final shown = filter.apply(trades).length;
    final notifier = ref.read(journalViewProvider.notifier);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'filter trades',
          child: GlassSurface(
            radius: DojiRadius.sheet,
            tint: DojiColors.elevated2,
            fillOpacity: 0.9,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3D42),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('filter trades', style: DojiType.title.copyWith(fontSize: 24)),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(10, 0),
                        child: DojiIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'close',
                          outlined: false,
                          background: Colors.transparent,
                          foreground: DojiColors.textSecondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final g in FilterGroup.values)
                            if (_options(g, symbols, setups, accounts.keys.toList()).isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Semantics(
                                header: true,
                                child: Text(
                                  '${g.label.toUpperCase()}${filter.of(g).isEmpty ? '' : ' · ${filter.of(g).length}'}',
                                  style: DojiType.label.copyWith(fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final o in _options(g, symbols, setups, accounts.keys.toList()))
                                    DojiChoiceChip(
                                      label: switch (g) {
                                        FilterGroup.pair => instrumentLabel(o),
                                        FilterGroup.account => accounts[o] ?? o,
                                        _ => o,
                                      },
                                      selected: filter.of(g).contains(o),
                                      mono: g.mono,
                                      style: DojiChoiceStyle.chip,
                                      onTap: () => notifier.toggleFilter(g, o),
                                    ),
                                ],
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DojiButton(
                    label: 'show $shown ${shown == 1 ? 'trade' : 'trades'}',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  DojiButton(
                    label: 'clear filters',
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: filter.isEmpty ? null : notifier.clearFilter,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

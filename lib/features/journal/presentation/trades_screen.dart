import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/trade_filter.dart';
import 'filters_sheet.dart';
import 'journal_controller.dart';
import 'widgets/journal_page.dart';
import 'widgets/trade_row.dart';

/// Every trade, newest first, with the filters (Doji Trade Journal › trades).
class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(journalControllerProvider);
    final view = ref.watch(journalViewProvider);
    final symbol = ref.watch(accountCurrencyProvider).symbol;
    final shown = view.filter.apply(all);
    final active = view.filter.activeGroups;

    return JournalPage(
      children: [
        JournalBackBar(
          label: 'journal',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.journal),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(header: true, child: Text('trades', style: DojiType.title)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${shown.length} of ${all.length}', style: DojiType.hint.copyWith(fontSize: 13)),
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: active == 0 ? 'filters' : 'filters · $active',
                selected: active > 0,
                icon: Icons.tune_rounded,
                onTap: () => unawaited(showFiltersSheet(context)),
              ),
              for (final g in FilterGroup.values) ...[
                const SizedBox(width: 6),
                _FilterChip(
                  label: view.filter.chipLabel(g),
                  selected: false,
                  outlined: view.filter.of(g).isNotEmpty,
                  onTap: () => unawaited(showFiltersSheet(context)),
                ),
              ],
            ],
          ),
        ),
        if (shown.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerminalLine(
                all.isEmpty ? 'no trades yet.' : 'no trades match these filters.',
                liveRegion: false,
              ),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 8),
                DojiButton(
                  label: 'clear filters',
                  variant: DojiButtonVariant.ghost,
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: ref.read(journalViewProvider.notifier).clearFilter,
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              for (final t in shown)
                TradeRow(
                  trade: t,
                  unit: view.unit,
                  currencySymbol: symbol,
                  onTap: () => unawaited(context.push(Routes.tradeDetail(t.id))),
                ),
            ],
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final bool outlined;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? DojiColors.bg : (outlined ? DojiColors.textPrimary : DojiColors.textSecondary);
    return DojiPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(DojiRadius.pill),
      semanticLabel: 'filter: $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DojiColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(DojiRadius.pill),
          border: Border.all(color: selected || outlined ? DojiColors.textPrimary : DojiColors.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(
              label,
              style: DojiType.chip.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

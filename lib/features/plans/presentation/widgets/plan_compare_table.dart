import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../domain/plans.dart';

/// Design system: `PlanCompareTable` (Doji Plans spec). The full feature
/// matrix with the plan header pinned above the scrolling rows; tapping a
/// column selects that plan. Cells are ✓, — or short text; the selected
/// column is tinted green 7%, rows are 44 minimum. Included / not included is
/// also spoken, never colour alone.
class PlanCompareTable extends StatelessWidget {
  const PlanCompareTable({
    super.key,
    required this.selected,
    required this.period,
    required this.onSelect,
    this.footer,
  });

  final PlanId selected;
  final BillingPeriod period;
  final ValueChanged<PlanId> onSelect;
  final Widget? footer;

  static const _labelWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: const BoxDecoration(
            color: Color(0xDB050607),
            border: Border(bottom: BorderSide(color: DojiColors.separator)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        period == BillingPeriod.annual ? 'per year' : 'per month',
                        style: DojiType.hint,
                      ),
                    ),
                  ),
                ),
                for (final plan in plans)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: _Head(
                        plan: plan,
                        period: period,
                        on: plan.id == selected,
                        onTap: () => onSelect(plan.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final row in featureRows) _Row(row: row, selected: selected),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                child: Text(
                  '✓ included · — not included. prices in usd and zar; store prices can differ by region.',
                  style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.plan, required this.period, required this.on, required this.onTap});

  final Plan plan;
  final BillingPeriod period;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(10));
    return DojiPressable(
      onPressed: onTap,
      borderRadius: radius,
      checked: on,
      inMutuallyExclusiveGroup: true,
      semanticLabel: '${plan.name}, ${plan.usd(period)}, ${plan.zar(period)}',
      pressedScale: 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: on ? DojiColors.greenTint : DojiColors.elevated1,
          borderRadius: radius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan.name,
              textAlign: TextAlign.center,
              style: DojiType.callout.copyWith(
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: DojiColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              plan.usd(period),
              textAlign: TextAlign.center,
              style: DojiType.hint.copyWith(fontSize: 11, color: DojiColors.textPrimary),
            ),
            Text(plan.zar(period), textAlign: TextAlign.center, style: DojiType.hint.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.selected});

  final FeatureRow row;
  final PlanId selected;

  @override
  Widget build(BuildContext context) {
    final spoken = [
      for (var i = 0; i < plans.length; i++)
        '${plans[i].name} ${switch (row.cells[i]) {
          true => 'included',
          false => 'not included',
          final Object v => v,
        }}',
    ].join(', ');
    return Semantics(
      container: true,
      label: '${row.feature}: $spoken',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DojiColors.elevated2)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: PlanCompareTable._labelWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Text(row.feature, style: DojiType.callout.copyWith(fontSize: 13, height: 1.3)),
                    ),
                  ),
                ),
                for (var i = 0; i < plans.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 2),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      alignment: Alignment.center,
                      color: plans[i].id == selected ? const Color(0x122FD67B) : Colors.transparent,
                      child: Text(
                        switch (row.cells[i]) {
                          true => '✓',
                          false => '—',
                          final Object v => v.toString(),
                        },
                        textAlign: TextAlign.center,
                        style: DojiType.hint.copyWith(
                          fontSize: 11,
                          height: 1.25,
                          color: row.cells[i] == false ? DojiColors.textSecondary : DojiColors.textPrimary,
                        ),
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

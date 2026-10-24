import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';

/// One row of [PlanVsActual].
class PlanRow {
  const PlanRow(this.label, {required this.plan, required this.actual, this.kept});

  final String label;
  final String plan;
  final String actual;

  /// Check (true), cross (false) or no mark (null).
  final bool? kept;
}

/// Doji Trade Journal › `PlanVsActual`: entry, stop, target, result and time
/// in trade, plan beside actual, with a check or cross per row (the mark has
/// a spoken label, colour is never the only signal).
class PlanVsActual extends StatelessWidget {
  const PlanVsActual({super.key, required this.rows});

  final List<PlanRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Column(
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 12,
                  child: Text('PLAN VS ACTUAL', style: DojiType.label.copyWith(fontSize: 11)),
                ),
                Expanded(flex: 10, child: Text('plan', style: DojiType.label.copyWith(fontSize: 11))),
                Expanded(flex: 10, child: Text('actual', style: DojiType.label.copyWith(fontSize: 11))),
                const SizedBox(width: 28),
              ],
            ),
          ),
        ),
        for (final r in rows)
          Semantics(
            container: true,
            label:
                '${r.label}: plan ${r.plan}, actual ${r.actual}'
                '${r.kept == null ? '' : (r.kept! ? ', as planned' : ', differs from plan')}',
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DojiColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 12, child: Text(r.label, style: DojiType.body.copyWith(fontSize: 14))),
                    Expanded(
                      flex: 10,
                      child: Text(
                        r.plan,
                        style: DojiType.data.copyWith(fontSize: 13, color: DojiColors.textSecondary),
                      ),
                    ),
                    Expanded(flex: 10, child: Text(r.actual, style: DojiType.data.copyWith(fontSize: 13))),
                    SizedBox(
                      width: 28,
                      child: r.kept == null
                          ? null
                          : Icon(
                              r.kept! ? Icons.check_rounded : Icons.close_rounded,
                              size: 18,
                              color: r.kept! ? DojiColors.dojiGreen : DojiColors.tiltOrange,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

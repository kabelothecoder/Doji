import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/pair_brief.dart';

/// Design system: `ConditionRow(status)` in a card, as on handoff 1b › 03.
/// Each row is glyph shape + status word + colour: three channels, so it
/// reads without colour.
class ConditionList extends StatelessWidget {
  const ConditionList({super.key, required this.conditions});

  final List<EntryCondition> conditions;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < conditions.length; i++) ConditionRow(condition: conditions[i], divider: i > 0),
      ],
    ),
  );
}

/// Design system: `ConditionRow(status: met | notMet | waiting)`.
class ConditionRow extends StatelessWidget {
  const ConditionRow({super.key, required this.condition, this.divider = false});

  final EntryCondition condition;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final status = condition.status;
    final (Color word, Color? fill, Border? border, Color glyph, IconData icon) = switch (status) {
      ConditionStatus.met => (
        DojiColors.dojiGreen,
        DojiColors.dojiGreen,
        null,
        DojiColors.bg,
        Icons.check_rounded,
      ),
      ConditionStatus.notMet => (
        DojiColors.tiltOrange,
        null,
        Border.all(color: DojiColors.tiltOrange, width: 1.5),
        DojiColors.tiltOrange,
        Icons.close_rounded,
      ),
      ConditionStatus.waiting => (
        DojiColors.textSecondary,
        null,
        Border.all(color: DojiColors.textTertiary),
        DojiColors.textSecondary,
        Icons.more_horiz_rounded,
      ),
    };
    return Semantics(
      container: true,
      label: '${condition.text}, ${status.label.toLowerCase()}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: divider ? const Border(top: BorderSide(color: DojiColors.divider)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: fill,
                  border: border,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: glyph),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  condition.text,
                  style: DojiType.callout.copyWith(color: DojiColors.textPrimary, height: 1.35),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                status.label,
                style: DojiType.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: word),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

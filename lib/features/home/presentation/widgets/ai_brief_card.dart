import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../markets/domain/instrument_catalog.dart';
import '../../domain/home_models.dart';
import 'home_card.dart';

/// Design spec `AiBriefCard`: the brief for the selected instrument, measured
/// against the user's strategy. Conditions are shape + word; the "not
/// financial advice" footer is required.
///
/// PLACEHOLDER: conditions and times are sample data.
/// TODO(next-slice): brief from the `ai-brief` edge function.
class AiBriefCard extends StatefulWidget {
  const AiBriefCard({super.key, required this.instruments, required this.conditions});

  final List<String> instruments;
  final List<BriefCondition> conditions;

  @override
  State<AiBriefCard> createState() => _AiBriefCardState();
}

class _AiBriefCardState extends State<AiBriefCard> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final met = widget.conditions.where((c) => c.met).length;
    final total = widget.conditions.length;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: HomeEyebrow('AI BRIEF')),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (var i = 0; i < widget.instruments.length && i < 3; i++)
                      _InstrumentChip(
                        instrument: widget.instruments[i],
                        selected: i == _selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
              children: [
                const TextSpan(text: 'measured against your strategy: '),
                // TODO(next-slice): the parsed strategy's name.
                TextSpan(
                  text: '[strategy name]',
                  style: DojiType.config.copyWith(color: DojiColors.textPrimary),
                ),
                TextSpan(text: '. $met of $total conditions are in place.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final c in widget.conditions) _ConditionRow(c),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Text('not financial advice · updated [time]', style: DojiType.hint.copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _InstrumentChip extends StatelessWidget {
  const _InstrumentChip({required this.instrument, required this.selected, required this.onTap});

  final String instrument;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return Semantics(
      button: true,
      selected: selected,
      label: instrumentLabel(instrument),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? DojiColors.dojiGreen : DojiColors.separator),
                ),
                child: Text(
                  instrumentLabel(instrument),
                  style: DojiType.hint.copyWith(
                    color: selected ? DojiColors.textPrimary : DojiColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow(this.c);

  final BriefCondition c;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${c.text}, ${c.met ? 'met' : 'waiting'}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DojiColors.divider)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.met ? DojiColors.dojiGreen : Colors.transparent,
                  border: Border.all(
                    color: c.met ? DojiColors.dojiGreen : DojiColors.textSecondary,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.text,
                  style: DojiType.callout.copyWith(fontSize: 14, color: DojiColors.textPrimary),
                ),
              ),
              Text(
                c.met ? 'met' : 'waiting',
                style: DojiType.hint.copyWith(
                  color: c.met ? DojiColors.textPrimary : DojiColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

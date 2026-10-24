import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../markets/domain/currency.dart';
import '../../domain/onboarding_catalog.dart';
import '../../domain/onboarding_step.dart';
import '../../domain/risk.dart';
import '../../domain/rules.dart';
import 'step_input.dart';

/// Handoff 4c: `SegmentedButton · InfoNote(tone: tilt) · DojiStepper × 2`.
/// "Above 2% shows a calm tilt-orange note, never a block."
class RiskInput extends StatelessWidget {
  const RiskInput(this.args, {super.key});

  final StepInputArgs args;

  void _set(Map<String, Object?> patch) => args.onChanged({...args.draftMap, ...patch});

  @override
  Widget build(BuildContext context) {
    final risk = A.mapNum(args.draft, 'riskPct');
    final custom = args.draftMap['custom'] == true;
    final maxTrades = A.mapNum(args.draft, 'maxTrades') ?? 3;
    final dailyLoss = A.mapNum(args.draft, 'dailyLoss') ?? 2;
    final note = riskNote(risk);
    final currency = AccountCurrency.fromCode(A.mapStr(args.draft, 'currency')) ?? AccountCurrency.fallback;

    final chips = [
      for (var i = 0; i < riskOptions.length; i++)
        () {
          final o = riskOptions[i];
          final isCustom = o.value == 'custom';
          final selected = isCustom ? custom : (!custom && risk == double.parse(o.value));
          return DojiChoiceChip(
            label: isCustom && custom && risk != null ? '${fmtPct(risk)}%' : o.label,
            mono: true,
            center: !args.wide,
            exclusive: true,
            keyHint: '${i + 1}',
            minHeight: args.wide ? 60 : 52,
            selected: selected,
            onTap: () => _set(
              isCustom
                  ? {'custom': true, 'riskPct': risk != null && custom ? risk : 3.0}
                  : {'custom': false, 'riskPct': double.parse(o.value)},
            ),
          );
        }(),
    ];

    final steppers = [
      DojiStepper(
        label: 'max trades/day',
        value: maxTrades,
        min: 1,
        max: 20,
        semanticUnit: 'trades',
        onChanged: (v) => _set({'maxTrades': v.round()}),
      ),
      DojiStepper(
        label: 'daily loss limit',
        value: dailyLoss,
        min: 0.5,
        max: 10,
        step: 0.5,
        format: (v) => '${fmtPct(v)}%',
        semanticUnit: 'percent',
        onChanged: (v) => _set({'dailyLoss': v}),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!args.wide) ...[
          Text('RISK PER TRADE', style: DojiType.label.copyWith(letterSpacing: 0.5)),
          const SizedBox(height: 8),
        ],
        EqualColumns(columns: 4, gap: args.wide ? 10 : 8, children: chips),
        if (custom) ...[
          const SizedBox(height: 4),
          DojiSlider(
            compact: true,
            label: 'custom risk per trade',
            value: risk ?? 3,
            min: 0.25,
            max: 5,
            divisions: 19,
            format: (v) => '${fmtPct(v)}%',
            onChanged: (v) => _set({'riskPct': (v * 4).round() / 4}),
          ),
        ],
        if (note != null) ...[SizedBox(height: args.wide ? 14 : 12), InfoNote(text: note)],
        SizedBox(height: args.wide ? 14 : 12),
        if (args.wide)
          EqualColumns(columns: 2, gap: 10, children: steppers)
        else ...[
          steppers[0],
          const SizedBox(height: 12),
          steppers[1],
        ],
        SizedBox(height: args.wide ? 14 : 12),
        // The currency the balance is held in: sizing converts into it.
        Text('ACCOUNT CURRENCY', style: DojiType.label.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        EqualColumns(
          columns: 4,
          gap: args.wide ? 10 : 8,
          children: [
            for (final c in AccountCurrency.values)
              DojiChoiceChip(
                label: c.code,
                mono: true,
                center: true,
                exclusive: true,
                minHeight: 48,
                selected: currency == c,
                onTap: () => _set({'currency': c.code}),
              ),
          ],
        ),
      ],
    );
  }
}

/// Handoff 4d: `RulesCard(version: 1)` — Card(elevated-1, radius 24).
/// "Tapping a rule jumps to its line in profile.doji."
class RulesCard extends StatelessWidget {
  const RulesCard({super.key, required this.answers, required this.onEditStep});

  final Answers answers;
  final ValueChanged<String> onEditStep;

  @override
  Widget build(BuildContext context) {
    final rules = buildRules(answers);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.sheet),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('your rules v1', style: DojiType.headline)),
              ),
              Flexible(
                child: Text(
                  rulesTag(answers),
                  style: DojiType.hint.copyWith(color: DojiColors.dojiGreen),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "no rules yet. that's fine — add them anytime.",
                style: DojiType.callout,
              ), // doji voice
            ),
          for (var i = 0; i < rules.length; i++)
            DojiPressable(
              onPressed: () => onEditStep(rules[i].stepId),
              semanticLabel: 'rule ${i + 1}: ${rules[i].text}',
              semanticHint: 'edit',
              pressedScale: 1,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DojiTokens.of(context).minTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          (i + 1).toString().padLeft(2, '0'),
                          style: DojiType.hint.copyWith(fontSize: 15, height: 1.4),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rules[i].text,
                          style: DojiType.callout.copyWith(color: DojiColors.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Text('v1 · editable anytime in profile.doji', style: DojiType.hint),
          ),
        ],
      ),
    );
  }
}

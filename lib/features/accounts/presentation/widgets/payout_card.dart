import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../home/presentation/widgets/home_card.dart';
import '../../domain/payout_readiness.dart';

/// "PAYOUT RULES": the distance to each rule a prop payout needs, one line
/// each, with its standing as a word (colour is never the only signal).
class PayoutCard extends StatelessWidget {
  const PayoutCard({super.key, required this.rules});

  final List<RuleDistance> rules;

  @override
  Widget build(BuildContext context) => HomeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeEyebrow('PAYOUT RULES'),
        for (final r in rules) ...[const SizedBox(height: 10), PayoutRuleRow(rule: r)],
      ],
    ),
  );
}

class PayoutRuleRow extends StatelessWidget {
  const PayoutRuleRow({super.key, required this.rule});

  final RuleDistance rule;

  @override
  Widget build(BuildContext context) {
    final color = switch (rule.standing) {
      RuleStanding.kept => DojiColors.dojiGreen,
      RuleStanding.close || RuleStanding.broken => DojiColors.tiltOrange,
      RuleStanding.notSet => DojiColors.textSecondary,
    };
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(rule.line, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
          ),
          const SizedBox(width: 12),
          Text(rule.standing.label, style: DojiType.hint.copyWith(color: color)),
        ],
      ),
    );
  }
}

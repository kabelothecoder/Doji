import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';

/// Handoff 1b `AiBriefSection`: a numbered mono label over doji's output
/// (`>` prompt, Geist Mono). [tilt] is the risk note: orange label and prompt.
class BriefSection extends StatelessWidget {
  const BriefSection({
    super.key,
    required this.number,
    required this.title,
    this.text,
    this.child,
    this.trailing,
    this.tilt = false,
  });

  /// '01'.
  final String number;

  /// 'MARKET CONTEXT'.
  final String title;

  /// doji's words, after a `>`.
  final String? text;

  /// Instead of [text] (the condition list).
  final Widget? child;

  /// Beside the label (the strategy chip).
  final Widget? trailing;
  final bool tilt;

  @override
  Widget build(BuildContext context) {
    final accent = tilt ? DojiColors.tiltOrange : DojiColors.dojiGreen;
    final label = Semantics(
      header: true,
      child: Text(
        '$number · $title',
        style: DojiType.label.copyWith(
          fontWeight: FontWeight.w400,
          color: tilt ? accent : DojiColors.textSecondary,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trailing == null)
          label
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [label, trailing!],
          ),
        const SizedBox(height: 8),
        if (text != null)
          Text.rich(
            TextSpan(
              style: DojiType.aiOutput.copyWith(color: DojiColors.textPrimary),
              children: [
                TextSpan(
                  text: '> ',
                  style: TextStyle(color: accent),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ?child,
      ],
    );
  }
}

/// The strategy name chip on 02 ("[Strategy name]").
class StrategyChip extends StatelessWidget {
  const StrategyChip(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: BorderRadius.circular(6)),
    child: Text(name, style: DojiType.hint.copyWith(fontSize: 11, color: DojiColors.textPrimary)),
  );
}

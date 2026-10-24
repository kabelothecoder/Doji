import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';

/// The Home card surface: elevated-1, 16 radius, 1px separator.
/// [borderColor] marks the card that wants attention (evening: green).
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = DojiColors.separator,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

/// Mono caps eyebrow: "AI BRIEF", "RULES TODAY".
class HomeEyebrow extends StatelessWidget {
  const HomeEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(header: true, child: Text(text, style: DojiType.label));
}

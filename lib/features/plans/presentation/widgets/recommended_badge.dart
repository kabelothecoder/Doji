import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';

/// Design system: `RecommendedBadge` (Doji Plans spec). Marks the one plan
/// picked from onboarding. Geist Mono 10, tracking .06em, green on green 12%,
/// radius 6. It is text, so colour is never the only signal.
class RecommendedBadge extends StatelessWidget {
  const RecommendedBadge({super.key, this.label = 'recommended'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: DojiColors.greenTint, borderRadius: BorderRadius.circular(6)),
    child: Text(
      label.toUpperCase(),
      style: DojiType.hint.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: DojiColors.dojiGreen,
      ),
    ),
  );
}

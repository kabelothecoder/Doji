import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: `RankPill` (ladder M1 Impulsive → MN Doji).
/// The current rank gets a green code badge, tint and hairline.
class RankPill extends StatelessWidget {
  const RankPill({super.key, required this.code, required this.name, this.current = true});

  final String code;
  final String name;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'rank $code, $name',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: current ? DojiColors.greenTint : DojiColors.elevated2,
            borderRadius: BorderRadius.circular(DojiRadius.pill),
            border: Border.all(color: current ? DojiColors.dojiGreen : DojiColors.separator),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: current ? DojiColors.dojiGreen : DojiColors.separator,
                  borderRadius: BorderRadius.circular(DojiRadius.pill),
                ),
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  style: DojiType.hint.copyWith(
                    fontWeight: FontWeight.w700,
                    color: current ? DojiColors.bg : DojiColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  style: DojiType.callout.copyWith(
                    color: DojiColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

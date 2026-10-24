import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/process_grade.dart';
import 'dashed_border.dart';

/// Doji Trade Journal › `ProcessGrade`: an A–F square. A and B are green, C
/// is grey, D and F are orange, and the letter is always drawn. A trade not
/// reviewed yet gets a dashed grey "—".
class ProcessGradeBox extends StatelessWidget {
  const ProcessGradeBox({super.key, required this.grade, this.size = 32, this.caption});

  final ProcessGrade? grade;
  final double size;

  /// Small word under the letter on the detail ("process").
  final String? caption;

  static Color colorOf(ProcessGrade? g) => switch (g) {
    null => DojiColors.textSecondary,
    ProcessGrade.a || ProcessGrade.b => DojiColors.dojiGreen,
    ProcessGrade.c => DojiColors.textSecondary,
    ProcessGrade.d || ProcessGrade.f => DojiColors.tiltOrange,
  };

  @override
  Widget build(BuildContext context) {
    final g = grade;
    final color = colorOf(g);
    final letter = Text(
      g?.letter ?? '—',
      style: DojiType.data.copyWith(
        color: color,
        fontSize: size * 0.44,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
    final inner = SizedBox(
      width: size,
      height: size,
      child: Center(
        child: caption == null
            ? letter
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  letter,
                  Text(caption!, style: DojiType.hint.copyWith(fontSize: 9)),
                ],
              ),
      ),
    );
    final radius = size / 3.5;
    return Semantics(
      container: true,
      label: g == null ? 'not graded yet' : 'process grade ${g.letter}',
      child: ExcludeSemantics(
        child: g == null
            ? DashedBorder(radius: radius, color: color, child: inner)
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: color, width: size > 40 ? 2 : 1.5),
                ),
                child: inner,
              ),
      ),
    );
  }
}

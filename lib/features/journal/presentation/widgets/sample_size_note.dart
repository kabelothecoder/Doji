import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import 'dashed_border.dart';

/// Doji Trade Journal › `SampleSizeNote`: a dashed mono note when there are
/// too few trades to read anything into. "only 9 trades — early signal".
class SampleSizeNote extends StatelessWidget {
  const SampleSizeNote({super.key, required this.count, this.threshold = 20, this.text});

  final int count;
  final int threshold;

  /// Replaces the default wording.
  final String? text;

  /// True when [count] is under [threshold].
  bool get isSmall => count < threshold;

  @override
  Widget build(BuildContext context) {
    final line = text ?? 'only $count ${count == 1 ? 'trade' : 'trades'} — early signal';
    return Semantics(
      container: true,
      label: line,
      child: ExcludeSemantics(
        child: DashedBorder(
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(line, style: DojiType.hint.copyWith(color: DojiColors.textSecondary)),
        ),
      ),
    );
  }
}

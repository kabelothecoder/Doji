import 'package:flutter/material.dart';

import '../theme/typography.dart';

/// Design system: `ConfigProgress` in the handoff's Flutter map
/// (`ProgressBarTerminal` in the brief): `[██████░░░░] 60% configured`.
class ProgressBarTerminal extends StatelessWidget {
  const ProgressBarTerminal({super.key, required this.fraction, this.suffix = 'configured', this.style});

  /// 0–1.
  final double fraction;
  final String suffix;
  final TextStyle? style;

  static String render(double fraction, {String suffix = 'configured'}) {
    final pct = (fraction.clamp(0, 1) * 100).round();
    final filled = (pct / 10).round();
    return '[${'█' * filled}${'░' * (10 - filled)}] $pct% $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (fraction.clamp(0, 1) * 100).round();
    return Semantics(
      label: '$pct percent $suffix',
      child: ExcludeSemantics(
        child: Text(
          render(fraction, suffix: suffix),
          style: style ?? DojiType.hint,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// AnimatedSize that respects reduce motion by not animating at all.
///
/// (AnimatedSize with Duration.zero re-dirties itself during layout, so the
/// reduced path must skip it rather than pass a zero duration.)
class DojiAnimatedSize extends StatelessWidget {
  const DojiAnimatedSize({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => DojiMotion.reduced(context)
      ? child
      : AnimatedSize(duration: duration, curve: curve, alignment: alignment, child: child);
}

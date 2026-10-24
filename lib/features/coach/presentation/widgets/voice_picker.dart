import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/coach.dart';

/// Handoff 1c `VoicePicker(SegmentedButton)`: male · female · coach on a glass
/// pill. The picked one is a white pill with dark text. Each segment's touch
/// area is the full height of the pill (the platform minimum); the drawn
/// pill inside it is 38 tall, as designed.
class VoicePicker extends StatelessWidget {
  const VoicePicker({super.key, required this.value, required this.onChanged});

  final CoachVoice value;
  final ValueChanged<CoachVoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return Semantics(
      container: true,
      label: 'coach voice',
      child: GlassSurface(
        radius: DojiRadius.pill,
        blur: 24,
        tint: DojiColors.elevated2,
        fillOpacity: 0.7,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in CoachVoice.values) ...[
                if (v.index > 0) const SizedBox(width: 2),
                _Segment(voice: v, selected: v == value, height: target, onTap: () => onChanged(v)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.voice, required this.selected, required this.height, required this.onTap});

  final CoachVoice voice;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = height - 6;
    return DojiPressable(
      onPressed: onTap,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      semanticLabel: '${voice.label} voice',
      showPressedOverlay: false,
      borderRadius: BorderRadius.circular(DojiRadius.pill),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height, minWidth: height),
        child: Center(
          widthFactor: 1,
          child: AnimatedContainer(
            duration: DojiMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 160),
            constraints: BoxConstraints(minHeight: pill),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? DojiColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(DojiRadius.pill),
            ),
            child: Text(
              voice.short,
              style: DojiType.config.copyWith(color: selected ? DojiColors.bg : DojiColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

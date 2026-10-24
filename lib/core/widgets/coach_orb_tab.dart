import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'doji_pressable.dart';

/// Design system: `CoachOrbTab` (Home spec): the centre tab, a raised 56pt
/// orb with a quiet green glow. Tap opens the coach; long-press opens voice
/// directly. [listening] swells the core.
class CoachOrbTab extends StatelessWidget {
  const CoachOrbTab({
    super.key,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
    this.listening = false,
    this.size = 56,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;
  final bool listening;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * 24 / 56 * (listening ? 1.2 : 1);
    // One button node: tap opens the coach, long-press opens it listening.
    return Semantics(
      container: true,
      button: true,
      label: 'coach',
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: DojiPressable(
            onPressed: onTap,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DojiColors.elevated1,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? DojiColors.dojiGreen : DojiColors.separator),
              ),
              child: Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  color: DojiColors.dojiGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: DojiColors.dojiGreen.withValues(alpha: 0.45), blurRadius: 18)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

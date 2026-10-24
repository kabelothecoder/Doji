import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';

/// Doji Trade Journal › `MistakeTagChip`: one of the ten tags, orange outline.
/// Selected adds a minus glyph and a tint, so state is never colour alone.
///
/// With [onTap] it is an input (44pt, the review sheet and filters); without
/// it, a small label on a trade row or detail.
class MistakeTagChip extends StatelessWidget {
  const MistakeTagChip({super.key, required this.tag, this.selected = false, this.onTap, this.large = false});

  final String tag;
  final bool selected;
  final VoidCallback? onTap;

  /// Bigger static chip (trade detail).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final input = onTap != null;
    final radius = BorderRadius.circular(input || large ? 10 : 6);
    final chip = Container(
      constraints: BoxConstraints(minHeight: input ? 44 : (large ? 28 : 22)),
      padding: EdgeInsets.symmetric(horizontal: input ? 14 : (large ? 10 : 7), vertical: input ? 8 : 2),
      decoration: BoxDecoration(
        color: selected ? DojiColors.orangeTint : Colors.transparent,
        borderRadius: radius,
        border: Border.all(color: selected ? DojiColors.tiltOrange : DojiColors.orangeHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.remove_rounded, size: 16, color: DojiColors.tiltOrange),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              tag,
              style: DojiType.chip.copyWith(
                fontSize: input ? 15 : (large ? 13 : 11),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
    if (!input) return chip;
    return DojiPressable(
      onPressed: onTap,
      borderRadius: radius,
      selected: selected,
      semanticLabel: 'mistake: $tag',
      activateOnEnter: false,
      child: chip,
    );
  }
}

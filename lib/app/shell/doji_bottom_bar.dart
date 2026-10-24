import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import 'main_tab.dart';

/// Phone navigation: five equal slots, the coach orb in the middle (design:
/// Doji Home Phone bottom bar). Selected = filled glyph + primary label.
class DojiBottomBar extends StatelessWidget {
  const DojiBottomBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onCoachVoice,
  });

  final MainTab selected;
  final ValueChanged<MainTab> onSelect;

  /// Long-press on the orb: the coach, already listening.
  final VoidCallback onCoachVoice;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DojiColors.bg,
        border: Border(top: BorderSide(color: DojiColors.separator)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final tab in MainTab.values)
                Expanded(
                  child: tab.isOrb
                      ? _OrbSlot(
                          selected: selected == tab,
                          onTap: () => onSelect(tab),
                          onLongPress: onCoachVoice,
                        )
                      : _TabSlot(
                          tab: tab,
                          selected: selected == tab,
                          minHeight: target,
                          onTap: () => onSelect(tab),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({required this.tab, required this.selected, required this.minHeight, required this.onTap});

  final MainTab tab;
  final bool selected;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DojiColors.textPrimary : DojiColors.textSecondary;
    return DojiPressable(
      onPressed: onTap,
      selected: selected,
      semanticLabel: tab.label,
      showPressedOverlay: false,
      borderRadius: BorderRadius.circular(DojiRadius.chip),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight + 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.selectedIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tab.label, style: DojiType.hint.copyWith(fontSize: 11, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbSlot extends StatelessWidget {
  const _OrbSlot({required this.selected, required this.onTap, required this.onLongPress});

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DojiColors.textPrimary : DojiColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoachOrbTab(size: 52, selected: selected, onTap: onTap, onLongPress: onLongPress),
        const SizedBox(height: 3),
        ExcludeSemantics(
          child: Text('coach', style: DojiType.hint.copyWith(fontSize: 11, color: color)),
        ),
      ],
    );
  }
}

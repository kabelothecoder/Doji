import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import 'main_tab.dart';

/// Wide / Windows navigation: the bottom bar's five items as a vertical rail
/// on the left. The design has no separate rail artwork, so this reuses the
/// bar's glyphs, labels and `CoachOrbTab`. Selected = filled glyph, primary
/// label and a green-tint pill.
class DojiNavRail extends StatelessWidget {
  const DojiNavRail({super.key, required this.selected, required this.onSelect, required this.onCoachVoice});

  final MainTab selected;
  final ValueChanged<MainTab> onSelect;
  final VoidCallback onCoachVoice;

  static const double width = 88;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'main navigation',
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          color: DojiColors.bg,
          border: Border(right: BorderSide(color: DojiColors.separator)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const WordmarkHero(child: DojiWordmark(size: 16)),
              const SizedBox(height: 24),
              for (final tab in MainTab.values) ...[
                tab.isOrb
                    ? _OrbItem(
                        selected: selected == tab,
                        onTap: () => onSelect(tab),
                        onLongPress: onCoachVoice,
                      )
                    : _RailItem(tab: tab, selected: selected == tab, onTap: () => onSelect(tab)),
                const SizedBox(height: 8),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap});

  final MainTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DojiColors.textPrimary : DojiColors.textSecondary;
    return DojiPressable(
      onPressed: onTap,
      selected: selected,
      semanticLabel: tab.label,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      child: Container(
        width: 68,
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: selected ? DojiColors.greenTint : Colors.transparent,
          borderRadius: BorderRadius.circular(DojiRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.selectedIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 4),
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

class _OrbItem extends StatelessWidget {
  const _OrbItem({required this.selected, required this.onTap, required this.onLongPress});

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DojiColors.textPrimary : DojiColors.textSecondary;
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          CoachOrbTab(size: 48, selected: selected, onTap: onTap, onLongPress: onLongPress),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text('coach', style: DojiType.hint.copyWith(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}

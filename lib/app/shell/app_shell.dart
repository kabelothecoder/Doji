import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/layout.dart';
import '../../core/theme/tokens.dart';
import 'doji_bottom_bar.dart';
import 'doji_nav_rail.dart';
import 'main_tab.dart';

/// Frame around the five tabs. Wide screens and Windows (the plans rule:
/// always wide on Windows) get the side rail; phones get the bottom bar.
/// Each tab keeps its own state while you switch (StatefulShellRoute).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  MainTab get _selected => MainTab.values[shell.currentIndex];

  void _select(MainTab tab) {
    // Tapping the active tab again returns to its root.
    shell.goBranch(tab.index, initialLocation: tab.index == shell.currentIndex);
  }

  // TODO(next-slice): open the coach already listening (voice session).
  void _coachVoice() => _select(MainTab.coach);

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: wide
          ? Row(
              children: [
                DojiNavRail(selected: _selected, onSelect: _select, onCoachVoice: _coachVoice),
                Expanded(child: shell),
              ],
            )
          : shell,
      bottomNavigationBar: wide
          ? null
          : DojiBottomBar(selected: _selected, onSelect: _select, onCoachVoice: _coachVoice),
    );
  }
}

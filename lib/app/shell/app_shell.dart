import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/layout.dart';
import '../../core/theme/tokens.dart';
import '../routes.dart';
import 'doji_bottom_bar.dart';
import 'doji_nav_rail.dart';
import 'main_tab.dart';

/// Frame around the five tabs. Wide screens and Windows (the plans rule:
/// always wide on Windows) get the side rail; phones get the bottom bar.
/// Each tab keeps its own state while you switch (StatefulShellRoute). The
/// coach orb opens the coach as a full-screen cover over the current tab
/// (long-press: already listening).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  MainTab get _selected => MainTab.branches[shell.currentIndex];

  @override
  Widget build(BuildContext context) {
    void select(MainTab tab) {
      if (tab.isOrb) {
        context.push(Routes.coach);
        return;
      }
      // Tapping the active tab again returns to its root.
      final branch = MainTab.branches.indexOf(tab);
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
    }

    void coachVoice() => context.push(Routes.coachListening);

    final wide = isWideLayout(context);
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: wide
          ? Row(
              children: [
                DojiNavRail(selected: _selected, onSelect: select, onCoachVoice: coachVoice),
                // Its own semantics container: each branch page's barrier
                // blocks the semantics of whatever was painted before it,
                // which would hide the whole rail from screen readers.
                Expanded(child: Semantics(container: true, child: shell)),
              ],
            )
          : shell,
      bottomNavigationBar: wide
          ? null
          : DojiBottomBar(selected: _selected, onSelect: select, onCoachVoice: coachVoice),
    );
  }
}

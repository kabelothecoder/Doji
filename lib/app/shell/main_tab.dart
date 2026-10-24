import 'package:flutter/material.dart';

import '../routes.dart';

/// The five tabs (design: Doji Core Tabs / Doji Home Phone bottom bar).
/// The same items drive the phone bottom bar and the wide side rail.
enum MainTab {
  home('home', Icons.home_outlined, Icons.home_rounded, Routes.home),
  markets('markets', Icons.candlestick_chart_outlined, Icons.candlestick_chart_rounded, Routes.markets),
  coach('coach', Icons.circle_outlined, Icons.circle, Routes.coach),
  journal('journal', Icons.menu_book_outlined, Icons.menu_book_rounded, Routes.journal),
  me('me', Icons.person_outline_rounded, Icons.person_rounded, Routes.me);

  const MainTab(this.label, this.icon, this.selectedIcon, this.route);

  final String label;
  final IconData icon;

  /// Filled glyph when selected: state is shape + text, not colour alone.
  final IconData selectedIcon;
  final String route;

  /// The centre tab is drawn as the coach orb, not an icon.
  bool get isOrb => this == MainTab.coach;
}

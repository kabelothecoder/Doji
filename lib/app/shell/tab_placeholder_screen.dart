import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_info.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../routes.dart';
import 'main_tab.dart';

/// PLACEHOLDER for the me tab, a separate brief. Its design is in Claude
/// Design (Doji Core Tabs › 06, not synced yet).
/// TODO(next-slice): replace it with the me screen.
class TabPlaceholderScreen extends StatelessWidget {
  const TabPlaceholderScreen({super.key, required this.tab});

  final MainTab tab;

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
              children: [
                const SizedBox(height: 8),
                Semantics(header: true, child: Text(tab.label, style: DojiType.title)),
                const SizedBox(height: 14),
                TerminalLine('${tab.label} arrives in a later build.', liveRegion: false),
                if (tab == MainTab.me) ...[
                  const SizedBox(height: 24),
                  DojiButton(
                    label: 'account and settings',
                    variant: DojiButtonVariant.outline,
                    size: DojiButtonSize.regular,
                    onPressed: () => context.push(Routes.settings),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/platform/layout.dart';
import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_button.dart';
import '../../../../core/widgets/doji_pressable.dart';

/// The frame every journal screen shares: one scrolling column, centred and
/// capped in width. On Windows and wide windows it is the phone column with
/// room around it, until the Journal Engine workspace exists.
///
/// Built eagerly (a form keeps its focus while the keyboard moves the page).
/// TODO(next-slice): virtualise the trades list once journals reach thousands
/// of trades.
class JournalPage extends StatelessWidget {
  const JournalPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWideLayout(context) ? 640 : 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "‹ journal": the way back on a pushed screen, with an optional action on
/// the right. 44pt target.
class JournalBackBar extends StatelessWidget {
  const JournalBackBar({super.key, required this.label, required this.onBack, this.trailing});

  final String label;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Transform.translate(
        offset: const Offset(-8, 0),
        child: DojiPressable(
          onPressed: onBack,
          borderRadius: BorderRadius.circular(DojiRadius.pill),
          semanticLabel: 'back to $label',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left_rounded, size: 28, color: DojiColors.textPrimary),
                Text(label, style: DojiType.body.copyWith(fontSize: 16)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      const Spacer(),
      ?trailing,
    ],
  );
}

/// A small outline action ("edit review", "filters").
class JournalPillButton extends StatelessWidget {
  const JournalPillButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DojiButton(
    label: label,
    variant: DojiButtonVariant.outline,
    size: DojiButtonSize.small,
    expand: false,
    icon: icon == null ? null : Icon(icon, size: 16),
    onPressed: onPressed,
  );
}

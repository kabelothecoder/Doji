import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/domain/profile_doji.dart';

/// Design spec `HomeHeader`: greeting, rank pill and notifications.
/// The greeting switches to "evening" after [eveningFromHour].
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.name, required this.rank, required this.evening, this.onBell});

  final String name;
  final String rank;
  final bool evening;

  /// TODO(next-slice): notification centre. Null hides the bell.
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    final target = DojiTokens.of(context).minTarget;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: target),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(evening ? 'evening, $name' : 'hey, $name', style: DojiType.title),
                ),
                RankPill(code: rank, name: dojiRanks[rank] ?? ''),
              ],
            ),
          ),
          if (onBell != null)
            Transform.translate(
              offset: const Offset(10, 0),
              child: DojiIconButton(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'notifications',
                outlined: false,
                background: Colors.transparent,
                foreground: DojiColors.textSecondary,
                onPressed: onBell,
              ),
            ),
        ],
      ),
    );
  }
}

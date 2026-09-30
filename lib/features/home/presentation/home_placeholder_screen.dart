import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import '../../onboarding/presentation/onboarding_controller.dart';

final _savedProfileProvider = Provider<ProfileDoji?>(
  (ref) => ref.watch(onboardingRepositoryProvider).loadProfile(),
);

/// PLACEHOLDER. Home is a separate brief (design/handoff/Doji Hero Screens
/// .dc.html › 1a). This shows just enough to prove the hand-off worked: the
/// header, the rank, and today's lit Grid square.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(_savedProfileProvider) ?? const ProfileDoji();
    final now = DateTime.now();
    final first = firstSession(p.sessions, p.utcOffsetMinutes ?? now.timeZoneOffset.inMinutes);
    final opens = first == null
        ? ''
        : ' · ${first.label.toUpperCase()} OPENS ${hhmm(first.localOpen(p.utcOffsetMinutes ?? 0)!)}';
    final greeting = now.hour < 12
        ? 'good morning'
        : now.hour < 18
        ? 'good afternoon'
        : 'good evening';
    final initial = (p.name ?? 'd').characters.first.toUpperCase();
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;

    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 12, margin, 32),
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const WordmarkHero(child: DojiWordmark(size: 22)),
                      const Spacer(),
                      DojiIconButton(
                        icon: Icons.person_outline_rounded,
                        semanticLabel: 'Profile and settings ($initial)',
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}$opens',
                  style: DojiType.label,
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text('$greeting,\n${p.name ?? 'trader'}.', style: DojiType.largeTitle),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RankPill(code: p.rank, name: dojiRanks[p.rank] ?? ''),
                ),
                const SizedBox(height: 28),
                Text('DOJI GRID · THIS WEEK', style: DojiType.label),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      GridCell(
                        size: 16,
                        state: i == 0 && p.pledgedAt != null ? GridCellState.today : GridCellState.future,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                if (p.pendingSync) ...[
                  const TerminalLine('profile.doji lives on this device. sign in anytime to sync.'),
                  const SizedBox(height: 20),
                ],
                const _BriefPlaceholder(),
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  DojiButton(
                    label: 'reset onboarding (debug)',
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: () async {
                      await ref.read(onboardingControllerProvider.notifier).reset();
                      ref.invalidate(_savedProfileProvider);
                      if (context.mounted) context.go(Routes.intro);
                    },
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

/// The auth handoff's own Home stand-in: striped panel, "home · separate brief".
class _BriefPlaceholder extends StatelessWidget {
  const _BriefPlaceholder();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'home arrives in a later build',
    child: Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DojiRadius.sheet),
        border: Border.all(color: DojiColors.separator),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _StripesPainter(),
        child: Center(child: Text('home · separate brief', style: DojiType.hint)),
      ),
    ),
  );
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = DojiColors.elevated1);
    final p = Paint()
      ..color = const Color(0xFF131518)
      ..strokeWidth = 10 / 1.4142;
    for (double x = -size.height; x < size.width + size.height; x += 20) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => false;
}

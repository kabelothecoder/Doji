import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../domain/plans.dart';
import 'plans_controller.dart';

/// Handoff "success": `> pro unlocked._`, one success haptic, "go home".
/// The trial is on; the reminder promise is repeated, not embellished.
class PurchaseSuccessScreen extends ConsumerStatefulWidget {
  const PurchaseSuccessScreen({super.key});

  @override
  ConsumerState<PurchaseSuccessScreen> createState() => _PurchaseSuccessScreenState();
}

class _PurchaseSuccessScreenState extends ConsumerState<PurchaseSuccessScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(hapticsProvider).success());
  }

  /// "basic", "pro", "elite": the short word, not the full plan name.
  static String _word(PlanId id) => switch (id) {
    PlanId.basic => 'basic',
    PlanId.elite => 'elite',
    _ => 'pro',
  };

  @override
  Widget build(BuildContext context) {
    final word = _word(ref.watch(entitlementProvider).plan);
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        centerBody: true,
        body: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: DojiColors.dojiGreen),
              child: const Icon(Icons.check_rounded, size: 30, color: DojiColors.bg),
            ),
          ),
          const SizedBox(height: 24),
          TerminalLine(
            '$word unlocked.',
            tone: TerminalTone.primary,
            cursor: true,
            style: DojiType.title.copyWith(fontFamily: DojiFonts.mono, fontSize: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "your $trialDays-day trial is on. we'll remind you a day before it ends.",
            style: DojiType.body.copyWith(color: DojiColors.textSecondary),
          ),
        ],
        actions: [
          DojiButton(
            label: 'go home',
            variant: DojiButtonVariant.neutral,
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
    );
  }
}

/// Handoff "failed or cancelled": a cancelled sheet is not an error. Nothing
/// was charged and the setup is saved either way.
class PurchaseFailedScreen extends ConsumerWidget {
  const PurchaseFailedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => context.canPop() ? context.pop() : context.go(Routes.plans);
    return AuthScaffold(
      centerBody: true,
      body: [
        const TerminalLine('purchase not completed.', cursor: true),
        const SizedBox(height: 14),
        Semantics(header: true, child: Text('no charge was made.', style: DojiType.largeTitle)),
        const SizedBox(height: 14),
        Text(
          "$storeName didn't finish the purchase. your setup is saved either way.",
          style: DojiType.body.copyWith(color: DojiColors.textSecondary),
        ),
      ],
      actions: [
        DojiButton(label: 'try again', variant: DojiButtonVariant.neutral, onPressed: retry),
        DojiButton(
          label: 'continue free',
          variant: DojiButtonVariant.outline,
          onPressed: () => context.go(Routes.home),
        ),
        DojiButton(
          label: 'restore purchases',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          onPressed: () => unawaited(ref.read(entitlementProvider.notifier).restore()),
        ),
      ],
    );
  }
}

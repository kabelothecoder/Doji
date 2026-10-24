import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/billing_repository.dart';
import '../../domain/plans.dart';
import '../plans_controller.dart';

/// Free needs no store; a paid plan opens the OS purchase sheet and then
/// lands on success, or on "no charge was made".
Future<void> runCheckout(BuildContext context, WidgetRef ref) async {
  final state = ref.read(plansControllerProvider);
  if (!state.paid) {
    context.go(Routes.home);
    return;
  }
  final outcome = await ref.read(plansControllerProvider.notifier).purchase();
  if (!context.mounted || outcome == null) return;
  if (outcome == PurchaseOutcome.purchased) {
    context.go(Routes.planSuccess);
  } else {
    unawaited(context.push(Routes.planFailed));
  }
}

/// The pinned bottom bar of the plans and compare screens: the call to
/// action, the renewal terms, and the always-available way out.
class PlansFooter extends ConsumerWidget {
  const PlansFooter({super.key, this.ctaLabel, this.showLinks = true});

  /// Defaults to the plans screen's wording.
  final String? ctaLabel;
  final bool showLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(plansControllerProvider);
    final label = ctaLabel ?? (s.paid ? 'start $trialDays-day free trial' : 'continue with free');
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xC7050607),
        border: Border(top: BorderSide(color: DojiColors.separator)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DojiButton(label: label, onPressed: s.busy ? null : () => unawaited(runCheckout(context, ref))),
              const SizedBox(height: 10),
              Text(
                termsLine(s.selected, s.period, storeName: storeName),
                textAlign: TextAlign.center,
                style: DojiType.hint.copyWith(fontFamily: DojiFonts.sans, height: 1.45),
              ),
              if (showLinks) const PlansLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

/// continue free · restore.
class PlansLinks extends ConsumerWidget {
  const PlansLinks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      DojiButton(
        label: 'continue free',
        variant: DojiButtonVariant.text,
        size: DojiButtonSize.small,
        expand: false,
        onPressed: () => context.go(Routes.home),
      ),
      const SizedBox(width: 8),
      DojiButton(
        label: 'restore',
        variant: DojiButtonVariant.text,
        size: DojiButtonSize.small,
        expand: false,
        semanticLabel: 'restore purchases',
        onPressed: () => unawaited(ref.read(entitlementProvider.notifier).restore()),
      ),
    ],
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../app_lock/presentation/app_lock_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';

/// The account part of settings from handoff A11 / A12 (the rest of settings
/// is a later brief): account, app lock, coach voice; sign out and delete.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _voices = {'calm_male': 'calm male', 'calm_female': 'calm female', 'coach_tone': 'coach tone'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final lock = ref.watch(appLockControllerProvider);
    final plan = ref.watch(entitlementProvider).plan;
    final voice = ref.watch(onboardingRepositoryProvider).loadProfile()?.coach?.voice;
    void back() => context.canPop() ? context.pop() : context.go(Routes.home);

    final lockValue = switch (lock) {
      AppLockState(enabled: true, :final kind) => kind?.name ?? 'on',
      AppLockState(kindLoaded: true, kind: null) => 'unavailable',
      _ => 'off',
    };

    return AuthScaffold(
      leading: AuthLeading.back,
      onLeading: back,
      bodyGap: 0,
      body: [
        Semantics(header: true, child: Text('settings', style: DojiType.largeTitle)),
        const SizedBox(height: 20),
        _Group(
          rows: [
            _Row(
              label: 'account',
              value: user == null ? 'on this device only' : (user.email ?? user.method.name),
            ),
            _Row(
              label: 'app lock',
              value: lockValue,
              onTap: lock.kind == null ? null : () => unawaited(context.push(Routes.appLock)),
            ),
            if (voice != null) _Row(label: 'coach voice', value: _voices[voice] ?? voice),
          ],
        ),
        const SizedBox(height: 20),
        _Group(
          rows: [
            _Row(
              label: 'subscription',
              value: planOf(plan).name,
              onTap: () => unawaited(context.push(plan == PlanId.free ? Routes.plans : Routes.subscription)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Group(
          rows: user == null
              ? [_Row(label: 'sign in to sync', onTap: () => unawaited(context.push(Routes.signIn)))]
              : [
                  _Row(label: 'sign out', onTap: () => unawaited(showSignOutSheet(context, ref))),
                  _Row(
                    label: 'delete account',
                    color: DojiColors.tiltOrange,
                    onTap: () => unawaited(context.push(Routes.deleteAccount)),
                  ),
                ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DojiRadius.card),
    child: ColoredBox(
      color: DojiColors.elevated1,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: DojiColors.divider)),
              ),
              child: rows[i],
            ),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.onTap, this.color = DojiColors.textPrimary});

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: DojiType.body.copyWith(color: color)),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value!,
                style: DojiType.callout,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (onTap != null && value != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: DojiColors.textSecondary),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return MergeSemantics(child: content);
    }
    return DojiPressable(
      onPressed: onTap,
      semanticLabel: value == null ? label : '$label, $value',
      pressedScale: 1,
      child: content,
    );
  }
}

/// A11: "Glass sheet over settings. Sign out is not destructive to data, so
/// it stays neutral white."
Future<void> showSignOutSheet(BuildContext context, WidgetRef ref) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (context) => const _SignOutSheet(),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(accountActionsProvider).signOut();
  if (context.mounted) context.go(Routes.intro);
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Sign out',
          explicitChildNodes: true,
          child: GlassSurface(
            radius: 40,
            tint: DojiColors.elevated2,
            fillOpacity: 0.78,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: DojiColors.separator,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'sign out of doji?',
                    style: DojiType.headline.copyWith(fontSize: 22, letterSpacing: -0.44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'profile.doji stays in your account. sign in again to get it back on this ${PlatformInfo.deviceNoun}.',
                    style: DojiType.callout,
                  ),
                  const SizedBox(height: 20),
                  DojiButton(
                    label: 'sign out',
                    variant: DojiButtonVariant.neutral,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 12),
                  DojiButton(
                    label: 'cancel',
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

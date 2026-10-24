import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import 'app_lock_controller.dart';

/// Handoff A8a: "Explains the benefit, then the system prompt". Offered once
/// after the first session, and always reachable from settings → app lock,
/// where it doubles as the off switch.
class AppLockSetupScreen extends ConsumerStatefulWidget {
  const AppLockSetupScreen({super.key});

  @override
  ConsumerState<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends ConsumerState<AppLockSetupScreen> {
  void _leave() => context.canPop() ? context.pop() : context.go(Routes.home);

  Future<void> _turnOn() async {
    final ok = await ref.read(appLockControllerProvider.notifier).enable();
    if (ok && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    final kind = lock.kind;
    final device = PlatformInfo.deviceNoun;

    if (lock.kindLoaded && kind == null) {
      return AuthScaffold(
        prompt: 'security --app-lock',
        leading: AuthLeading.back,
        onLeading: _leave,
        centerBody: true,
        body: [
          const TerminalLine('app lock is unavailable.', tone: TerminalTone.tilt, cursor: true),
          const SizedBox(height: 12),
          Text(
            'set up a passcode, fingerprint or face on this $device first, then come back here.',
            style: DojiType.body.copyWith(color: DojiColors.textSecondary),
          ),
        ],
      );
    }

    final name = kind?.name ?? 'app lock';
    return AuthScaffold(
      prompt: 'security --app-lock',
      leading: AuthLeading.back,
      onLeading: _leave,
      centerBody: true,
      body: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: DojiColors.elevated1,
              borderRadius: BorderRadius.circular(DojiRadius.sheet),
              border: Border.all(color: DojiColors.separator),
            ),
            child: ExcludeSemantics(child: Icon(kind?.icon ?? Icons.lock_outline_rounded, size: 48)),
          ),
        ),
        const SizedBox(height: 28),
        AuthHeadline(
          lock.enabled ? '$name is on.' : 'lock doji with ${kind?.phrase ?? 'app lock'}.',
          sub: Text('your journal, rules and results stay private if someone else picks up your $device.'),
        ),
        const SizedBox(height: 28),
        Text.rich(
          TextSpan(
            style: DojiType.terminal.copyWith(fontSize: 13),
            children: const [
              TextSpan(
                text: '> ',
                style: TextStyle(color: DojiColors.dojiGreen),
              ),
              TextSpan(text: 'asks when you open doji\n'),
              TextSpan(
                text: '> ',
                style: TextStyle(color: DojiColors.dojiGreen),
              ),
              TextSpan(text: 'and after 5 min away'),
            ],
          ),
        ),
        if (lock.message case final msg?) ...[
          const SizedBox(height: 20),
          TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
        ],
      ],
      actions: [
        if (lock.enabled) ...[
          DojiButton(
            label: 'turn off $name',
            variant: DojiButtonVariant.outline,
            onPressed: () async {
              await ref.read(appLockControllerProvider.notifier).disable();
              if (context.mounted) _leave();
            },
          ),
          DojiButton(
            label: 'done',
            variant: DojiButtonVariant.text,
            size: DojiButtonSize.small,
            onPressed: _leave,
          ),
        ] else ...[
          DojiButton(
            label: 'turn on $name',
            onPressed: kind == null || lock.authenticating ? null : () => unawaited(_turnOn()),
          ),
          DojiButton(
            label: 'not now',
            variant: DojiButtonVariant.text,
            size: DojiButtonSize.small,
            onPressed: _leave,
          ),
          Text(
            'change anytime in settings → app lock',
            textAlign: TextAlign.center,
            style: DojiType.callout.copyWith(fontSize: 13),
          ),
        ],
      ],
    );
  }
}

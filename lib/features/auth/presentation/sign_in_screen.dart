import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// "Apple first, then Google, then a passwordless 6-digit email code" — the
/// same order on every platform.
const authMethodOrder = [AuthMethod.apple, AuthMethod.google, AuthMethod.email];

/// Handoff A1 "welcome back", reached from boot's "I already have an account".
/// "Close returns to onboarding K5. Icon above the headline stays quiet so the
/// Apple button is the first strong shape."
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _offline = false;
  AuthMethod? _last;

  AuthFlowController get _flow => ref.read(authFlowProvider.notifier);

  Future<void> _signIn(AuthMethod m) async {
    _last = m;
    if (m == AuthMethod.email) {
      unawaited(context.push('${Routes.email}?intent=${AuthIntent.signIn.name}'));
      return;
    }
    setState(() => _offline = false);
    final ok = await _flow.signInWith(m, AuthIntent.signIn);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.authenticated);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.onboarding);

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    if (flow.waitingFor case final m? when flow.intent == AuthIntent.signIn) {
      return AuthWaitingView(method: m, onCancel: _flow.cancelSheet);
    }
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_signIn(_last ?? AuthMethod.apple)),
        onBack: () => setState(() => _offline = false),
        onContinueOffline: _flow.canContinueOffline ? () => context.go(Routes.home) : null,
      );
    }

    return AuthScaffold(
      prompt: 'auth',
      leading: AuthLeading.close,
      onLeading: _close,
      centerBody: true,
      body: [
        const Align(alignment: Alignment.centerLeft, child: DojiAppIcon(size: 72)),
        const SizedBox(height: 28),
        AuthHeadline(
          'welcome back.',
          sub: Text('sign in to load your profile.doji on this ${PlatformInfo.deviceNoun}.'),
        ),
      ],
      actions: [
        if (flow.message case final msg?) TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
        for (final m in authMethodOrder)
          AuthMethodButton(
            method: m,
            title: AuthButtonTitle.signIn,
            onPressed: flow.busy ? null : () => unawaited(_signIn(m)),
          ),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('new here? ', style: DojiType.callout),
              DojiButton(
                label: 'start setup',
                variant: DojiButtonVariant.ghost,
                size: DojiButtonSize.small,
                expand: false,
                onPressed: _close,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

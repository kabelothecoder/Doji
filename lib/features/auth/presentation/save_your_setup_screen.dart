import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/domain/onboarding_catalog.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import 'auth_controller.dart';
import 'sign_in_screen.dart' show authMethodOrder;
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A2 (design/handoff/Doji Auth Screen iOS.dc.html › save): shown
/// after the pledge. "The card mirrors profile.doji exactly; 'continue without
/// account' keeps the setup local and asks again after the first session."
///
/// Already signed in (an account that had no setup yet): the setup goes
/// straight to the account and the screen hands off to A9b.
class SaveYourSetupScreen extends ConsumerStatefulWidget {
  const SaveYourSetupScreen({super.key});

  @override
  ConsumerState<SaveYourSetupScreen> createState() => _SaveYourSetupScreenState();
}

class _SaveYourSetupScreenState extends ConsumerState<SaveYourSetupScreen> {
  bool _offline = false;
  Future<bool> Function()? _last;

  AuthFlowController get _flow => ref.read(authFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (ref.read(authSessionProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run(_flow.saveToSignedInAccount)));
    }
  }

  Future<void> _run(Future<bool> Function() action) async {
    _last = action;
    setState(() => _offline = false);
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      context.go(ref.read(authFlowProvider).next);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  void _choose(AuthMethod m) {
    if (m == AuthMethod.email) {
      unawaited(context.push('${Routes.email}?intent=${AuthIntent.save.name}'));
    } else {
      unawaited(_run(() => _flow.signInWith(m, AuthIntent.save)));
    }
  }

  Future<void> _continueWithoutAccount() async {
    await ref.read(onboardingControllerProvider.notifier).finishLocally();
    if (mounted) context.go(Routes.plans);
  }

  Future<void> _backToPledge() async {
    await ref.read(onboardingControllerProvider.notifier).goTo(StepIds.pledge);
    if (mounted) context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    if (flow.waitingFor case final m? when flow.intent == AuthIntent.save) {
      return AuthWaitingView(method: m, onCancel: _flow.cancelSheet);
    }
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_run(_last ?? _flow.saveToSignedInAccount)),
        onBack: () => setState(() => _offline = false),
        onContinueOffline: () => unawaited(_continueWithoutAccount()),
      );
    }

    final state = ref.watch(onboardingControllerProvider);
    final all = state.configLines;
    // Mini profile: the lines the handoff shows, plus the starting rank.
    final keep = {'name', 'style', 'markets'};
    final mini = [
      for (final l in all.where((l) => keep.contains(l.keyName))) l.copyWith(highlighted: false),
      ConfigLineData(
        number: all.length + 1,
        keyName: 'rank',
        value: state.profile.rank,
        tone: ConfigValueTone.symbol,
        targetId: StepIds.compile,
        comment: '  # starting rank',
      ),
    ];
    final savingToAccount = flow.sending && flow.intent == AuthIntent.save;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !flow.busy) unawaited(_backToPledge());
      },
      child: AuthScaffold(
        prompt: '100% configured',
        promptAllAccent: true,
        bodyGap: 12,
        body: [
          const AuthHeadline(
            'save your setup.',
            sub: Text('sign in to keep profile.doji and sync it to your other devices.'),
          ),
          const SizedBox(height: 20),
          ProfileSaveCard(
            lines: mini,
            totalLines: all.length,
            status: savingToAccount ? ProfileSaveStatus.saving : ProfileSaveStatus.readyToSave,
          ),
        ],
        actions: [
          if (savingToAccount)
            const TerminalLine('saving profile.doji…', cursor: true)
          else ...[
            if (flow.message case final msg?) TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
            for (final m in authMethodOrder)
              AuthMethodButton(method: m, onPressed: flow.busy ? null : () => _choose(m)),
            DojiButton(
              label: 'continue without account',
              variant: DojiButtonVariant.text,
              size: DojiButtonSize.small,
              onPressed: flow.busy ? null : () => unawaited(_continueWithoutAccount()),
            ),
          ],
        ],
      ),
    );
  }
}

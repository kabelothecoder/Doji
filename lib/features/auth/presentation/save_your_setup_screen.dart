import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/domain/onboarding_catalog.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../data/todo_auth_repository.dart';
import '../domain/auth_repository.dart';

/// Handoff A2 (design/handoff/Doji Auth Screen iOS.dc.html › save): shown
/// after the pledge. "The card mirrors profile.doji exactly; 'continue without
/// account' keeps the setup local and asks again after the first session."
class SaveYourSetupScreen extends ConsumerStatefulWidget {
  const SaveYourSetupScreen({super.key});

  @override
  ConsumerState<SaveYourSetupScreen> createState() => _SaveYourSetupScreenState();
}

class _SaveYourSetupScreenState extends ConsumerState<SaveYourSetupScreen> {
  AuthMethod? _loading;
  String? _message;

  /// "Google first on Android (Credential Manager one-tap), Apple second."
  List<AuthMethod> get _order => PlatformInfo.isAndroid || PlatformInfo.isWindows
      ? const [AuthMethod.google, AuthMethod.apple, AuthMethod.email]
      : const [AuthMethod.apple, AuthMethod.google, AuthMethod.email];

  Future<void> _signIn(AuthMethod m) async {
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _loading = m;
      _message = null;
    });
    try {
      switch (m) {
        case AuthMethod.apple:
          await auth.signInWithApple();
        case AuthMethod.google:
          await auth.signInWithGoogle();
        case AuthMethod.email:
          // The email → 6-digit code flow is the next slice.
          throw const AuthUnavailable(
            'email codes arrive in the next build. your setup stays on this device.',
          );
      }
      if (mounted) context.go(Routes.home);
    } on AuthUnavailable catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _continueWithoutAccount() async {
    await ref.read(onboardingControllerProvider.notifier).finishLocally();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
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
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ref.read(onboardingControllerProvider.notifier).goTo(StepIds.pledge);
        if (context.mounted) context.go(Routes.onboarding);
      },
      child: Scaffold(
        backgroundColor: DojiColors.bg,
        body: Stack(
          children: [
            const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight - 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '> 100% configured',
                                      style: DojiType.hint.copyWith(
                                        fontSize: 13,
                                        color: DojiColors.dojiGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Semantics(
                                  header: true,
                                  child: Text('save your setup.', style: DojiType.largeTitle),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'sign in to keep profile.doji and sync it to your other devices.',
                                  style: DojiType.body.copyWith(color: DojiColors.textSecondary),
                                ),
                                const SizedBox(height: 20),
                                ProfileSaveCard(lines: mini, totalLines: all.length),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_message != null) ...[
                                  TerminalLine(_message!, tone: TerminalTone.tilt, cursor: true),
                                  const SizedBox(height: 16),
                                ],
                                for (final m in _order) ...[
                                  AuthMethodButton(
                                    method: m,
                                    loading: _loading == m,
                                    onPressed: _loading == null ? () => unawaited(_signIn(m)) : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                DojiButton(
                                  label: 'continue without account',
                                  variant: DojiButtonVariant.text,
                                  size: DojiButtonSize.small,
                                  onPressed: _loading == null
                                      ? () => unawaited(_continueWithoutAccount())
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

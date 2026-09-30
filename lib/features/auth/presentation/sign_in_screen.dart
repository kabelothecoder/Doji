import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/todo_auth_repository.dart';
import '../domain/auth_repository.dart';

/// Handoff A1 "welcome back" — reached from boot's "I already have an
/// account". STUB: the buttons explain that sign-in lands next slice.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  String? _message;

  List<AuthMethod> get _order => PlatformInfo.isAndroid || PlatformInfo.isWindows
      ? const [AuthMethod.google, AuthMethod.apple, AuthMethod.email]
      : const [AuthMethod.apple, AuthMethod.google, AuthMethod.email];

  Future<void> _signIn(AuthMethod m) async {
    final auth = ref.read(authRepositoryProvider);
    try {
      switch (m) {
        case AuthMethod.apple:
          await auth.signInWithApple();
        case AuthMethod.google:
          await auth.signInWithGoogle();
        case AuthMethod.email:
          throw const AuthUnavailable('email codes arrive in the next build.');
      }
      if (mounted) context.go(Routes.home);
    } on AuthUnavailable catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.onboarding);

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Text.rich(
                              TextSpan(
                                style: DojiType.hint.copyWith(fontSize: 13),
                                children: const [
                                  TextSpan(
                                    text: '> ',
                                    style: TextStyle(color: DojiColors.dojiGreen),
                                  ),
                                  TextSpan(text: 'auth'),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Transform.translate(
                              offset: const Offset(10, 0),
                              child: DojiIconButton(
                                icon: Icons.close_rounded,
                                semanticLabel: 'Close',
                                background: Colors.transparent,
                                foreground: DojiColors.textSecondary,
                                onPressed: _close,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 48),
                              const DojiAppIcon(size: 72),
                              const SizedBox(height: 28),
                              Semantics(
                                header: true,
                                child: Text('welcome back.', style: DojiType.largeTitle),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'sign in to load your profile.doji on this phone.',
                                style: DojiType.body.copyWith(color: DojiColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        TerminalLine(_message!, tone: TerminalTone.tilt, cursor: true),
                        const SizedBox(height: 16),
                      ],
                      for (final m in _order) ...[
                        AuthMethodButton(
                          method: m,
                          title: AuthButtonTitle.signIn,
                          onPressed: () => unawaited(_signIn(m)),
                        ),
                        const SizedBox(height: 12),
                      ],
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

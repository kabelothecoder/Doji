import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A3: "Keyboard opens on entry. Send is disabled until the value
/// looks like an email; return also sends."
class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key, required this.intent});

  final AuthIntent intent;

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  late final TextEditingController _email = TextEditingController(text: ref.read(authFlowProvider).email);
  bool _offline = false;

  AuthFlowController get _flow => ref.read(authFlowProvider.notifier);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!looksLikeEmail(_email.text)) return;
    setState(() => _offline = false);
    _flow.setEmail(_email.text);
    final ok = await _flow.sendCode(widget.intent);
    if (!mounted) return;
    if (ok) {
      unawaited(context.push(Routes.code));
    } else if (ref.read(authFlowProvider).linked != null) {
      unawaited(context.push(Routes.authExists));
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.signIn);

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_send()),
        onBack: () => setState(() => _offline = false),
        onContinueOffline: _flow.canContinueOffline
            ? () async {
                await _flow.continueOffline();
                if (context.mounted) context.go(Routes.home);
              }
            : null,
      );
    }

    final valid = looksLikeEmail(_email.text);
    return AuthScaffold(
      prompt: 'auth --email',
      leading: AuthLeading.back,
      onLeading: _back,
      body: [
        const SizedBox(height: 8),
        const AuthHeadline(
          "what's your email?",
          sub: Text("we'll send a 6-digit code. no password to remember."),
        ),
        const SizedBox(height: 24),
        const AuthFieldLabel('email'),
        const SizedBox(height: 8),
        AutofillGroup(
          child: DojiTextField(
            controller: _email,
            autofocus: true,
            large: false,
            textStyle: DojiType.body.copyWith(fontSize: 19),
            hint: 'you@example.com',
            semanticLabel: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.send,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_send()),
          ),
        ),
        if (flow.message case final msg?) ...[
          const SizedBox(height: 16),
          TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
        ],
        const SizedBox(height: 16),
        DojiButton(
          label: flow.sending ? 'sending…' : 'send code',
          onPressed: valid && !flow.sending ? () => unawaited(_send()) : null,
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A4 – A4e. "Passwordless. One hidden field drives six boxes so paste
/// and one-time-code autofill work natively. Auto-submits on the sixth digit."
///
/// - A4 code entry, "resend in 0:30" + paste
/// - A4b wrong: orange boxes, attempts left; the next keystroke clears them
/// - A4c expired: field locked, the only action is a new code
/// - A4d locked after 5 wrong codes: 15-minute live countdown
/// - A4e resend: the countdown becomes a link at 0:00
class CodeEntryScreen extends ConsumerStatefulWidget {
  const CodeEntryScreen({super.key});

  @override
  ConsumerState<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends ConsumerState<CodeEntryScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final Timer _tick;
  bool _offline = false;
  String? _hint;

  AuthFlowController get _flow => ref.read(authFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Drives "resend in 0:29" and the lock countdown; 250ms so the second
    // changes on time.
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _offline = false;
      _hint = null;
    });
    final ok = await _flow.verify(code);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.authenticated);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _offline = false;
      _hint = null;
    });
    final ok = await _flow.sendCode(ref.read(authFlowProvider).intent);
    if (!mounted) return;
    if (ok) {
      _code.clear();
      _focus.requestFocus();
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  /// "paste accepts any string containing 6 digits".
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = OtpCodeField.digitsIn(data?.text);
    if (!mounted) return;
    if (digits == null) {
      setState(() => _hint = 'no 6-digit code on the clipboard.');
      return;
    }
    _code.text = digits;
    _flow.codeEdited();
    await _verify(digits);
  }

  void _back() {
    _flow.codeEdited();
    context.canPop() ? context.pop() : context.go(Routes.email);
  }

  /// A4d "use another method": back to the screen the flow started on.
  void _anotherMethod() {
    final entry = ref.read(authFlowProvider).intent == AuthIntent.save ? Routes.save : Routes.signIn;
    final router = GoRouter.of(context);
    if (router.canPop()) router.pop();
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_code.text.length == 6 ? _verify(_code.text) : _resend()),
        onBack: () => setState(() => _offline = false),
        onContinueOffline: _flow.canContinueOffline
            ? () async {
                await _flow.continueOffline();
                if (context.mounted) context.go(Routes.home);
              }
            : null,
      );
    }

    final lockLeft = remaining(flow.lockedUntil);
    final status = flow.codeStatus == CodeStatus.locked && lockLeft == Duration.zero
        ? CodeStatus.expired
        : flow.codeStatus;
    final resendLeft = remaining(flow.ticket?.resendAt);
    final fieldState = switch (status) {
      CodeStatus.wrong => OtpFieldState.wrong,
      CodeStatus.expired || CodeStatus.locked => OtpFieldState.disabled,
      _ => OtpFieldState.idle,
    };

    final List<Widget> below = switch (status) {
      CodeStatus.verifying => [const TerminalLine('checking code…', cursor: true)],
      CodeStatus.wrong => [
        TerminalLine(
          "that code didn't match. ${flow.attemptsLeft} ${flow.attemptsLeft == 1 ? 'try' : 'tries'} left.",
          tone: TerminalTone.tilt,
          cursor: true,
        ),
      ],
      CodeStatus.expired => [
        const TerminalLine(
          'that code expired. codes last 10 minutes.',
          tone: TerminalTone.tilt,
          cursor: true,
        ),
        const SizedBox(height: 16),
        DojiButton(label: 'send a new code', onPressed: flow.sending ? null : () => unawaited(_resend())),
      ],
      CodeStatus.locked => [
        TerminalLine(
          'too many attempts. try again in ${mmss(lockLeft)}.',
          tone: TerminalTone.tilt,
          cursor: true,
        ),
        const SizedBox(height: 16),
        Text('this protects your account. you can still sign in another way.', style: DojiType.callout),
        const SizedBox(height: 24),
        DojiButton(
          label: 'use another method',
          variant: DojiButtonVariant.outline,
          onPressed: _anotherMethod,
        ),
      ],
      CodeStatus.idle when resendLeft > Duration.zero => [
        Row(
          children: [
            Expanded(
              child: Text(
                'resend in ${mmss(resendLeft)}',
                style: DojiType.terminal.copyWith(fontSize: 14, height: 1.3),
              ),
            ),
            _PasteButton(onPressed: () => unawaited(_paste())),
          ],
        ),
      ],
      CodeStatus.idle => [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-12, 0),
            child: DojiButton(
              label: 'resend code',
              icon: const Icon(Icons.refresh_rounded),
              variant: DojiButtonVariant.ghost,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: flow.sending ? null : () => unawaited(_resend()),
            ),
          ),
        ),
        Text('nothing yet? check spam and promotions.', style: DojiType.callout),
      ],
    };

    return AuthScaffold(
      prompt: 'auth --code',
      leading: AuthLeading.back,
      onLeading: _back,
      body: [
        const SizedBox(height: 8),
        AuthHeadline(
          'check your email.',
          sub: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('we sent a 6-digit code to '),
              Text('${flow.email.trim()}.', style: const TextStyle(color: DojiColors.textPrimary)),
              const SizedBox(width: 4),
              DojiButton(
                label: 'change',
                variant: DojiButtonVariant.ghost,
                size: DojiButtonSize.small,
                expand: false,
                semanticLabel: 'change email',
                onPressed: _back,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OtpCodeField(
          controller: _code,
          focusNode: _focus,
          autofocus: true,
          state: fieldState,
          onChanged: (_) {
            _flow.codeEdited();
            if (_hint != null) setState(() => _hint = null);
          },
          onCompleted: (code) => unawaited(_verify(code)),
        ),
        const SizedBox(height: 16),
        ...below,
        if (_hint case final hint?) ...[const SizedBox(height: 12), TerminalLine(hint)],
        if (flow.message case final msg?) ...[
          const SizedBox(height: 12),
          TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
        ],
      ],
    );
  }
}

/// "paste" chip: elevated-1, hairline, radius 10, 44pt.
class _PasteButton extends StatelessWidget {
  const _PasteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DojiRadius.chip);
    return DojiPressable(
      onPressed: onPressed,
      borderRadius: radius,
      semanticLabel: 'paste code',
      child: Container(
        constraints: BoxConstraints(minHeight: DojiTokens.of(context).minTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: radius,
          border: Border.all(color: DojiColors.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_paste_rounded, size: 18, color: DojiColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              'paste',
              style: DojiType.callout.copyWith(color: DojiColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

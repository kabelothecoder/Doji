import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/domain/formatting.dart' show dayLabel;
import '../domain/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A5 "signed up with another method": the email belongs to an
/// Apple / Google account. "One button for that method; no account linking
/// UI here."
class LinkedMethodScreen extends ConsumerStatefulWidget {
  const LinkedMethodScreen({super.key});

  @override
  ConsumerState<LinkedMethodScreen> createState() => _LinkedMethodScreenState();
}

class _LinkedMethodScreenState extends ConsumerState<LinkedMethodScreen> {
  bool _offline = false;

  AuthFlowController get _flow => ref.read(authFlowProvider.notifier);

  Future<void> _continue(AuthMethod m) async {
    setState(() => _offline = false);
    final ok = await _flow.signInWith(m, ref.read(authFlowProvider).intent);
    if (!mounted) return;
    if (ok) {
      context.go(ref.read(authFlowProvider).next);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.email);

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    final linked = flow.linked;
    if (flow.waitingFor case final m?) return AuthWaitingView(method: m, onCancel: _flow.cancelSheet);
    if (linked == null) {
      // Reached without a lookup (deep link, restored route): nothing to offer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _back();
      });
      return const SizedBox.shrink();
    }
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_continue(linked.method)),
        onBack: () => setState(() => _offline = false),
      );
    }

    final name = _methodName(linked.method);
    return AuthScaffold(
      prompt: 'auth --lookup',
      leading: AuthLeading.back,
      onLeading: _back,
      body: [
        const SizedBox(height: 8),
        AuthHeadline(
          "you've been here before.",
          sub: Text('you signed up with $name last time. use it again to load your setup.'),
        ),
        const SizedBox(height: 24),
        LinkedMethodCard(method: linked),
      ],
      actions: [
        if (flow.message case final msg?) TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
        AuthMethodButton(
          method: linked.method,
          onPressed: flow.busy ? null : () => unawaited(_continue(linked.method)),
        ),
        DojiButton(label: 'use a different email', variant: DojiButtonVariant.ghost, onPressed: _back),
      ],
    );
  }
}

String _methodName(AuthMethod m) => switch (m) {
  AuthMethod.apple => 'Apple',
  AuthMethod.google => 'Google',
  AuthMethod.email => 'email',
};

/// Design system: `LinkedMethodCard` (auth component spec, A5). The method,
/// the email and when it was last used.
class LinkedMethodCard extends StatelessWidget {
  const LinkedMethodCard({super.key, required this.method});

  final LinkedMethod method;

  @override
  Widget build(BuildContext context) {
    final last = method.lastUsedAt?.toLocal();
    final lastText = last == null
        ? null
        : DateUtils.isSameDay(last, clock.now())
        ? 'today'
        : dayLabel(last);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: DojiSpace.s4, vertical: DojiSpace.s3),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _methodName(method.method),
                  style: DojiType.body.copyWith(color: DojiColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(method.email, style: DojiType.terminal.copyWith(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          if (lastText != null) ...[
            const SizedBox(width: DojiSpace.s3),
            Text(
              'LAST USED\n$lastText',
              textAlign: TextAlign.right,
              style: DojiType.terminal.copyWith(fontSize: 11, height: 1.4, letterSpacing: 0.44),
            ),
          ],
        ],
      ),
    );
  }
}

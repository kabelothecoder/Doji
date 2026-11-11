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
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_states.dart';

/// Handoff A6 "keep this device's setup?": "only when a guest profile exists
/// locally and the account has its own. Defaults to this device because it
/// is the most recent." No back: the sign-in already happened, one setup
/// has to be picked.
class KeepSetupScreen extends ConsumerStatefulWidget {
  const KeepSetupScreen({super.key});

  @override
  ConsumerState<KeepSetupScreen> createState() => _KeepSetupScreenState();
}

class _KeepSetupScreenState extends ConsumerState<KeepSetupScreen> {
  bool _keepDevice = true;
  bool _offline = false;
  ProfileDoji? _remote;

  Future<void> _keep() async {
    setState(() => _offline = false);
    final ok = await ref.read(authFlowProvider.notifier).resolveMerge(keepDevice: _keepDevice);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.authenticated);
    } else if (ref.read(authFlowProvider).offline) {
      setState(() => _offline = true);
    }
  }

  String _when(DateTime? d) {
    if (d == null) return 'earlier';
    final local = d.toLocal();
    return DateUtils.isSameDay(local, clock.now()) ? 'today' : dayLabel(local);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowProvider);
    // Kept from the first build: the choice clears `pending` before this
    // screen navigates away, and that must not look like a restored route.
    final remote = _remote ??= flow.pending?.result.remoteProfile;
    if (remote == null) {
      // Nothing to choose (restored route): carry on to the save screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.save);
      });
      return const SizedBox.shrink();
    }
    if (_offline) {
      return AuthOfflineView(
        onRetry: () => unawaited(_keep()),
        onBack: () => setState(() => _offline = false),
      );
    }

    final device = ref.watch(onboardingControllerProvider);
    final options = [
      (
        keepDevice: true,
        title: 'this device',
        meta: 'profile.doji · today · ${device.configLines.length} lines · rank ${device.profile.rank}',
      ),
      (
        keepDevice: false,
        title: 'your account',
        meta: 'profile.doji · ${_when(remote.completedAt)} · rank ${remote.rank}',
      ),
    ];

    return PopScope(
      canPop: false,
      child: AuthScaffold(
        prompt: 'sync --conflict',
        body: [
          const SizedBox(height: 8),
          const AuthHeadline(
            "keep this device's setup?",
            sub: Text(
              'you set doji up here as a guest, and your account already has a setup. pick one to keep.',
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            container: true,
            label: 'setup to keep',
            child: Column(
              children: [
                for (final o in options) ...[
                  _SetupOption(
                    title: o.title,
                    meta: o.meta,
                    selected: _keepDevice == o.keepDevice,
                    onTap: flow.sending ? null : () => setState(() => _keepDevice = o.keepDevice),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('the other setup is removed. you can edit any line afterwards.', style: DojiType.callout),
        ],
        actions: [
          if (flow.message case final msg?) TerminalLine(msg, tone: TerminalTone.tilt, cursor: true),
          DojiButton(
            label: flow.sending
                ? 'saving…'
                : _keepDevice
                ? "keep this device's setup"
                : "keep your account's setup",
            onPressed: flow.sending ? null : () => unawaited(_keep()),
          ),
        ],
      ),
    );
  }
}

/// One radio card: green ring and border when selected, the word "selected"
/// for screen readers (colour is never the only signal).
class _SetupOption extends StatelessWidget {
  const _SetupOption({required this.title, required this.meta, required this.selected, required this.onTap});

  final String title;
  final String meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DojiColors.dojiGreen : DojiColors.separator;
    final radius = BorderRadius.circular(DojiRadius.card);
    return DojiPressable(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      onPressed: onTap,
      borderRadius: radius,
      semanticLabel: '$title. $meta',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DojiSpace.s4),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: radius,
          border: Border.all(color: color),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: DojiColors.dojiGreen),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DojiType.body.copyWith(color: DojiColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(meta, style: DojiType.terminal.copyWith(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

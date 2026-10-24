import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';

/// Design system: `DeleteAccountFlow` (auth component spec, A12a – A12d).
/// "Account deletion is in-app, as Apple requires, and revokes the Sign in
/// with Apple token." ExplainStep → TypeConfirmStep → DojiAlert → DoneStep.

/// "The App Store billing note is required because deletion does not cancel
/// subscriptions." Each store gets its own wording.
String storeBillingNote() {
  if (PlatformInfo.isAndroid) {
    return 'subscribed through Google Play? cancel in Play Store → Payments & subscriptions first. '
        "deleting doji doesn't stop Google Play billing.";
  }
  if (PlatformInfo.isWindows) {
    return 'subscribed through the Microsoft Store? cancel in your Microsoft account first. '
        "deleting doji doesn't stop Microsoft billing.";
  }
  return 'subscribed through the App Store? cancel in Settings → Apple Account first. '
      "deleting doji doesn't stop Apple billing.";
}

/// A12a "what goes": "Lists every data type erased."
class DeleteExplainScreen extends ConsumerWidget {
  const DeleteExplainScreen({super.key});

  static const items = [
    (Icons.description_outlined, 'profile.doji and your rules'),
    (Icons.menu_book_outlined, 'journal, trade logs and screenshots'),
    (Icons.forum_outlined, 'coaching history and voice settings'),
    (Icons.key_outlined, 'sign-in methods and app lock'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final who = user?.email ?? 'this account';
    void back() => context.canPop() ? context.pop() : context.go(Routes.settings);

    return AuthScaffold(
      prompt: 'account --delete',
      promptAccent: DojiColors.tiltOrange,
      leading: AuthLeading.back,
      onLeading: back,
      body: [
        const SizedBox(height: 8),
        AuthHeadline(
          'delete your account.',
          sub: Text("this erases everything tied to $who. it can't be undone."),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(DojiRadius.card),
          child: ColoredBox(
            color: DojiColors.elevated1,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : const Border(top: BorderSide(color: DojiColors.divider)),
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(child: Icon(items[i].$1, size: 20, color: DojiColors.textSecondary)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(items[i].$2, style: DojiType.body.copyWith(fontSize: 16, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        InfoNote(text: storeBillingNote()),
      ],
      actions: [
        DojiButton(
          label: 'continue',
          variant: DojiButtonVariant.cautionOutline,
          onPressed: () => unawaited(context.push(Routes.deleteConfirm)),
        ),
        DojiButton(
          label: 'keep my account',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          autofocus: true,
          onPressed: back,
        ),
      ],
    );
  }
}

/// A12b + A12c + deleting. "Button enables only when the field equals
/// 'delete' (trimmed, any case). Autocorrect off." Then the final alert.
class DeleteConfirmScreen extends ConsumerStatefulWidget {
  const DeleteConfirmScreen({super.key});

  static bool matches(String v) => v.trim().toLowerCase() == 'delete';

  @override
  ConsumerState<DeleteConfirmScreen> createState() => _DeleteConfirmScreenState();
}

class _DeleteConfirmScreenState extends ConsumerState<DeleteConfirmScreen> {
  final _text = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!DeleteConfirmScreen.matches(_text.text) || _deleting) return;
    final sure = await showDojiAlert(
      context,
      title: 'delete permanently?',
      message: "your account and all its data will be erased. this can't be undone.",
      destructiveLabel: 'delete',
    );
    if (!sure || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(accountActionsProvider).deleteAccount();
      if (mounted) context.go(Routes.accountDeleted);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e is AuthOffline ? 'connection lost. nothing was deleted. try again.' : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = DeleteConfirmScreen.matches(_text.text);
    void back() => context.canPop() ? context.pop() : context.go(Routes.deleteAccount);
    return PopScope(
      canPop: !_deleting,
      child: AuthScaffold(
        prompt: 'account --delete --confirm',
        promptAccent: DojiColors.tiltOrange,
        leading: AuthLeading.back,
        onLeading: _deleting ? null : back,
        body: [
          const SizedBox(height: 8),
          AuthHeadline(
            'type delete to confirm.',
            titleSpan: TextSpan(
              children: [
                const TextSpan(text: 'type '),
                TextSpan(
                  text: 'delete',
                  style: DojiType.largeTitle.copyWith(
                    fontFamily: DojiFonts.mono,
                    color: DojiColors.tiltOrange,
                    letterSpacing: -1,
                  ),
                ),
                const TextSpan(text: ' to confirm.'),
              ],
            ),
            sub: const Text('so it only happens on purpose.'),
          ),
          const SizedBox(height: 24),
          DojiTextField(
            controller: _text,
            autofocus: true,
            large: false,
            accent: DojiColors.tiltOrange,
            textStyle: DojiType.data.copyWith(fontSize: 20, fontWeight: FontWeight.w400),
            semanticLabel: 'Type delete to confirm',
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_confirm()),
          ),
          const SizedBox(height: 16),
          if (_deleting) ...[
            const TerminalLine('erasing…', tone: TerminalTone.tilt, cursor: true),
            const SizedBox(height: 16),
          ],
          if (_error case final err?) ...[
            TerminalLine(err, tone: TerminalTone.tilt, cursor: true),
            const SizedBox(height: 16),
          ],
          DojiButton(
            label: 'delete account',
            variant: DojiButtonVariant.caution,
            onPressed: ok && !_deleting ? () => unawaited(_confirm()) : null,
          ),
        ],
      ),
    );
  }
}

/// A12d: "Local storage wiped, tokens revoked. Done returns to the splash as
/// a new install."
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AuthScaffold(
      centerBody: true,
      body: [
        TerminalLine('account deleted.', cursor: true, style: DojiType.terminal.copyWith(fontSize: 15)),
        const SizedBox(height: 16),
        const AuthHeadline(
          'your data is gone.',
          sub: Text(
            'profile.doji, your journal and your coaching history are erased. backups clear within 30 days.',
          ),
        ),
      ],
      actions: [
        DojiButton(
          label: 'done',
          variant: DojiButtonVariant.outline,
          autofocus: true,
          onPressed: () => context.go(Routes.intro),
        ),
      ],
    ),
  );
}

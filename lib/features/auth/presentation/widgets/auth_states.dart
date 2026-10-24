import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import 'auth_scaffold.dart';

/// A2b: "The OS draws the Sign in with Apple sheet. Doji only shows a waiting
/// line behind it; cancel returns to the previous screen with no error."
///
/// The quiet cancel is for the browser flows (Apple on Android, both on
/// Windows), where no system sheet is there to close.
class AuthWaitingView extends StatelessWidget {
  const AuthWaitingView({super.key, required this.method, required this.onCancel});

  final AuthMethod method;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    prompt: 'auth',
    onLeading: onCancel,
    body: [
      const SizedBox(height: 40),
      TerminalLine(
        'waiting for ${method == AuthMethod.google ? 'google' : 'apple'}…',
        cursor: true,
        style: DojiType.terminal.copyWith(fontSize: 17, height: 1.5),
      ),
    ],
    actions: [
      DojiButton(
        label: 'cancel',
        variant: DojiButtonVariant.text,
        size: DojiButtonSize.small,
        onPressed: onCancel,
      ),
    ],
  );
}

/// A10: "Shown when any auth call fails on network. 'continue offline' is
/// available only when a local setup exists."
class AuthOfflineView extends StatelessWidget {
  const AuthOfflineView({super.key, required this.onRetry, this.onContinueOffline, this.onBack});

  final VoidCallback onRetry;

  /// Null hides "continue offline" (no setup on this device to fall back to).
  final VoidCallback? onContinueOffline;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    prompt: 'auth',
    leading: onBack == null ? AuthLeading.none : AuthLeading.back,
    onLeading: onBack,
    centerBody: true,
    body: [
      const ExcludeSemantics(child: Icon(Icons.wifi_off_rounded, size: 32, color: DojiColors.tiltOrange)),
      const SizedBox(height: 16),
      TerminalLine(
        'connection lost.\ntry again.',
        tone: TerminalTone.tilt,
        cursor: true,
        style: DojiType.question,
      ),
      const SizedBox(height: 16),
      Text(
        onContinueOffline == null
            ? 'nothing was lost.'
            : 'nothing was lost. your setup is still on this device.',
        style: DojiType.body.copyWith(color: DojiColors.textSecondary),
      ),
    ],
    actions: [
      DojiButton(label: 'try again', onPressed: onRetry, autofocus: true),
      if (onContinueOffline != null)
        DojiButton(
          label: 'continue offline',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          onPressed: onContinueOffline,
        ),
    ],
  );
}

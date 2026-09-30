import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_pressable.dart';
import 'typing_text.dart';

enum AuthMethod { apple, google, email }

enum AuthButtonTitle { signIn, continueWith }

/// Design system: `AuthMethodButton` (auth component spec, A1 · A2 · A5).
///
/// Brand buttons keep their official sentence case; email stays lowercase.
/// STAND-IN glyphs: ship the official SignInWithAppleButton and Google's G
/// asset when real auth lands (see design/SOURCE.md › open items).
class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    super.key,
    required this.method,
    required this.onPressed,
    this.title = AuthButtonTitle.continueWith,
    this.loading = false,
  });

  final AuthMethod method;
  final AuthButtonTitle title;
  final VoidCallback? onPressed;
  final bool loading;

  String get label {
    final verb = title == AuthButtonTitle.signIn ? 'Sign in with' : 'Continue with';
    return switch (method) {
      AuthMethod.apple => '$verb Apple',
      AuthMethod.google => '$verb Google',
      AuthMethod.email => 'continue with email',
    };
  }

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    const googleFg = Color(0xFFE3E3E3);
    final (Color bg, Color fg, Color? border, TextStyle style) = switch (method) {
      AuthMethod.apple => (white, black, null, DojiType.button.copyWith(fontSize: 19, color: black)),
      AuthMethod.google => (
        const Color(0xFF131314),
        googleFg,
        const Color(0xFF8E918F),
        DojiType.button.copyWith(
          fontFamily: 'Roboto',
          fontFamilyFallback: const [DojiFonts.sans],
          fontWeight: FontWeight.w500,
          color: googleFg,
        ),
      ),
      AuthMethod.email => (Colors.transparent, DojiColors.textPrimary, DojiColors.separator, DojiType.button),
    };
    final Widget glyph = switch (method) {
      AuthMethod.apple => Icon(Icons.apple, size: 22, color: fg),
      AuthMethod.google => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
        child: const Text(
          'G',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
        ),
      ),
      AuthMethod.email => Icon(Icons.mail_outline_rounded, size: 22, color: fg),
    };
    final radius = BorderRadius.circular(DojiRadius.pill);
    return DojiPressable(
      onPressed: loading ? null : onPressed,
      borderRadius: radius,
      semanticLabel: loading ? '$label, loading' : label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(child: glyph),
            const SizedBox(width: 10),
            Flexible(
              child: loading
                  ? Text.rich(
                      TextSpan(
                        style: style,
                        children: [
                          const TextSpan(text: '…'),
                          WidgetSpan(
                            child: BlinkingCursor(color: fg, style: style),
                          ),
                        ],
                      ),
                    )
                  : Text(label, style: style, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

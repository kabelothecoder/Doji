import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'typing_text.dart';

enum TerminalTone { muted, primary, tilt }

/// Design system: `TerminalLine` (auth component spec; used on every screen).
///
/// `>` in doji-green (tilt: orange), Geist Mono, optional typing and cursor.
/// Status lines are live regions so screen readers announce errors and
/// state changes such as "connection lost".
class TerminalLine extends StatelessWidget {
  const TerminalLine(
    this.text, {
    super.key,
    this.tone = TerminalTone.muted,
    this.typing = false,
    this.cursor = false,
    this.style,
    this.charDelay = DojiMotion.typeChar,
    this.start = true,
    this.onDone,
    this.liveRegion = true,
  });

  final String text;
  final TerminalTone tone;
  final bool typing;
  final bool cursor;
  final TextStyle? style;
  final Duration charDelay;
  final bool start;
  final VoidCallback? onDone;
  final bool liveRegion;

  Color get _accent => tone == TerminalTone.tilt ? DojiColors.tiltOrange : DojiColors.dojiGreen;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DojiType.terminal).copyWith(
      color: tone == TerminalTone.muted ? DojiColors.textSecondary : DojiColors.textPrimary,
    );
    if (typing) {
      return TypingText(
        text,
        style: base,
        prefixColor: _accent,
        cursorColor: _accent,
        showCursor: cursor,
        charDelay: charDelay,
        start: start,
        onDone: onDone,
        liveRegion: liveRegion,
      );
    }
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: text,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: base,
            children: [
              TextSpan(
                text: '> ',
                style: TextStyle(color: _accent),
              ),
              TextSpan(text: text),
              if (cursor)
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: BlinkingCursor(color: _accent, style: base),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

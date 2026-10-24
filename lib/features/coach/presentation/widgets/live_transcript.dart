import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/coach.dart';

/// Handoff 1c `LiveTranscript`: "COACH SESSION · mm:ss", then the latest
/// exchange, oldest first. Two lines at most: what the coach asked and what
/// you are saying back, or what you said and the coach's reply. The words
/// the mic hears appear as you speak; the coach's reply types out while it
/// speaks. The whole transcript is kept for saving, not shown.
class LiveTranscript extends StatelessWidget {
  const LiveTranscript({
    super.key,
    required this.elapsed,
    required this.turns,
    required this.listening,
    required this.heard,
    required this.thinking,
    required this.speaking,
    required this.onCoachDone,
  });

  final Duration elapsed;

  /// Oldest first.
  final List<CoachTurn> turns;

  /// The mic is open: [heard] is the live line.
  final bool listening;
  final String heard;

  /// A reply is on its way.
  final bool thinking;

  /// The newest coach line is being spoken (typed).
  final bool speaking;
  final VoidCallback onCoachDone;

  static final _youStyle = DojiType.body.copyWith(color: DojiColors.textSecondary);
  static final _coachStyle = DojiType.body.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: -0.015 * 26,
    color: DojiColors.textPrimary,
  );

  static String clockOf(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final (i, t) in turns.indexed)
        t.speaker == CoachSpeaker.you
            ? _Line(label: 'YOU', child: _you(t.text, live: false))
            : _Line(
                label: 'COACH',
                coach: true,
                child: _coach(t.text, i, newest: i == turns.length - 1),
              ),
      if (listening) _Line(label: 'YOU', child: _you(heard, live: true)),
      if (thinking)
        _Line(
          label: 'COACH',
          coach: true,
          child: ExcludeSemantics(child: BlinkingCursor(style: _coachStyle)),
        ),
    ];
    final shown = items.length > 2 ? items.sublist(items.length - 2) : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'coach session, ${elapsed.inMinutes} min ${elapsed.inSeconds % 60} s',
          child: ExcludeSemantics(child: Text('COACH SESSION · ${clockOf(elapsed)}', style: DojiType.label)),
        ),
        for (final line in shown) ...[const SizedBox(height: 16), line],
      ],
    );
  }

  Widget _you(String text, {required bool live}) => Semantics(
    label: live ? (text.isEmpty ? 'listening' : 'you are saying: $text') : 'you said: $text',
    child: ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          style: _youStyle,
          children: [
            TextSpan(text: text),
            if (live)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Padding(
                  padding: EdgeInsets.only(left: text.isEmpty ? 0 : 2),
                  child: BlinkingCursor(style: _youStyle),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _coach(String text, int index, {required bool newest}) {
    if (newest && speaking) {
      return TypingText(
        text,
        key: ValueKey('coach-$index'),
        prefix: '',
        style: _coachStyle,
        cursorAfterDone: false,
        onDone: onCoachDone,
      );
    }
    return Semantics(
      label: 'coach: $text',
      child: ExcludeSemantics(child: Text(text, style: _coachStyle)),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.child, this.coach = false});

  final String label;
  final Widget child;
  final bool coach;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: DojiType.hint.copyWith(
            fontSize: 11,
            letterSpacing: 0.08 * 11,
            color: coach ? DojiColors.dojiGreen : DojiColors.textSecondary,
          ),
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

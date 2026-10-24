import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/typing_text.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Handoff A9 / A9b: "Two status lines fade in, the headline types at 45ms
/// per character, success haptic on the last character, Home after 3.6s."
/// A9b (new account) has no name line, "because the name was just entered".
///
/// Reduce motion: everything renders complete; the hand-off timing stays so
/// the lines can still be read.
class AuthSuccessScreen extends ConsumerStatefulWidget {
  const AuthSuccessScreen({super.key});

  static const total = Duration(milliseconds: 3600);
  static const charDelay = Duration(milliseconds: 45);

  @override
  ConsumerState<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends ConsumerState<AuthSuccessScreen> with SingleTickerProviderStateMixin {
  // preserve: with reduce motion Flutter would otherwise run this at 5% speed
  // and skip straight to Home; the text is already static in that mode.
  late final AnimationController _t =
      AnimationController(
          vsync: this,
          duration: AuthSuccessScreen.total,
          animationBehavior: AnimationBehavior.preserve,
        )
        ..addListener(_onTick)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _handOff();
        });
  bool _buzzed = false;
  bool _left = false;

  static const _headline = 'authenticated.';

  @override
  void initState() {
    super.initState();
    _t.forward();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  AuthOutcome? get _outcome => ref.read(authFlowProvider).outcome;

  String? get _welcome => switch (_outcome?.welcomeName) {
    null => null,
    '' => 'welcome back.',
    final n => 'welcome back, $n.',
  };

  Duration get _elapsed => AuthSuccessScreen.total * _t.value;

  /// Characters of [text] typed by now, starting at [start].
  int _typed(String text, Duration start) {
    if (DojiMotion.reduced(context)) return text.length;
    final ms = (_elapsed - start).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / AuthSuccessScreen.charDelay.inMilliseconds).floor().clamp(0, text.length);
  }

  /// 0 → 1 over [length] starting at [start].
  double _fade(Duration start, Duration length) {
    if (DojiMotion.reduced(context)) return 1;
    final p = (_elapsed - start).inMicroseconds / length.inMicroseconds;
    return Curves.easeOut.transform(p.clamp(0.0, 1.0));
  }

  void _onTick() {
    if (_buzzed) return;
    final last = _welcome;
    final done = last == null
        ? _typed(_headline, const Duration(milliseconds: 1000)) == _headline.length
        : _typed(last, const Duration(milliseconds: 1750)) == last.length;
    if (done) {
      _buzzed = true;
      unawaited(ref.read(hapticsProvider).success());
    }
  }

  void _handOff() {
    if (_left || !mounted) return;
    _left = true;
    context.go(_outcome?.destination ?? Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = ref.watch(authFlowProvider).outcome;
    if (outcome == null) {
      // Reached without a sign-in (restored route): nothing to report.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handOff());
      return const ColoredBox(color: DojiColors.bg);
    }
    final welcome = _welcome;
    final opening = switch (outcome.destination) {
      Routes.home => '→ opening home',
      Routes.plans => '→ opening plans',
      _ => '→ opening setup',
    };
    final mono24 = DojiType.question;

    return PopScope(
      canPop: false,
      child: AuthScaffold(
        centerBody: true,
        body: [
          AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              Widget faded(Duration start, Duration length, Widget child) {
                final v = _fade(start, length);
                return Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child),
                );
              }

              Widget typedLine(String text, Duration start, {required bool prefix, required bool cursor}) {
                final n = _typed(text, start);
                final started = n > 0 || DojiMotion.reduced(context);
                return Text.rich(
                  TextSpan(
                    style: mono24,
                    children: [
                      if (prefix)
                        TextSpan(
                          text: '> ',
                          style: TextStyle(color: started ? DojiColors.dojiGreen : Colors.transparent),
                        ),
                      TextSpan(text: text.substring(0, n)),
                      TextSpan(
                        text: text.substring(n),
                        style: const TextStyle(color: Colors.transparent),
                      ),
                      if (cursor && n == text.length)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: BlinkingCursor(style: mono24),
                        ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < outcome.statusLines.length; i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          faded(
                            Duration(milliseconds: 400 * i),
                            const Duration(milliseconds: 250),
                            Text.rich(
                              TextSpan(
                                style: DojiType.terminal,
                                children: [
                                  const TextSpan(
                                    text: '> ',
                                    style: TextStyle(color: DojiColors.dojiGreen),
                                  ),
                                  TextSpan(text: outcome.statusLines[i]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: ['authenticated.', ?welcome].join(' '),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          typedLine(
                            _headline,
                            const Duration(milliseconds: 1000),
                            prefix: true,
                            cursor: welcome == null,
                          ),
                          if (welcome != null) ...[
                            const SizedBox(height: 6),
                            typedLine(
                              welcome,
                              const Duration(milliseconds: 1750),
                              prefix: false,
                              cursor: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  faded(
                    const Duration(milliseconds: 2800),
                    const Duration(milliseconds: 300),
                    Text(opening, style: DojiType.hint),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

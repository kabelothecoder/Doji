import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Lets one tap anywhere on a screen finish every [TypingText] below it.
///
/// Wrap a screen in [TypingScope] and call [TypingSkipController.skip] from a
/// screen-level gesture detector.
class TypingSkipController extends ChangeNotifier {
  int _generation = 0;
  int get generation => _generation;

  void skip() {
    _generation++;
    notifyListeners();
  }
}

class TypingScope extends InheritedNotifier<TypingSkipController> {
  const TypingScope({super.key, required TypingSkipController controller, required super.child})
    : super(notifier: controller);

  static TypingSkipController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TypingScope>()?.notifier;
}

/// Design system: `TypewriterText` in the handoff's Flutter map, named
/// `TypingText` in the brief. Also used by [TerminalLine].
///
/// - types [text] at [charDelay] per char after an optional green `>` prefix
/// - tap it (or anywhere inside a [TypingScope]) to complete instantly
/// - screen readers get the full line at once through a live region
/// - reduce motion: full text immediately, solid cursor
/// - hidden characters keep their space, so the layout never jumps
class TypingText extends StatefulWidget {
  const TypingText(
    this.text, {
    super.key,
    this.style,
    this.prefix = '> ',
    this.prefixColor = DojiColors.dojiGreen,
    this.charDelay = DojiMotion.typeChar,
    this.start = true,
    this.showCursor = true,
    this.cursorAfterDone = true,
    this.cursorColor = DojiColors.dojiGreen,
    this.onDone,
    this.liveRegion = true,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;

  /// Printed instantly before the typed text. Empty string for none.
  final String prefix;
  final Color prefixColor;
  final Duration charDelay;

  /// Typing waits until this is true. Used to chain lines one after another.
  final bool start;
  final bool showCursor;

  /// Keep a blinking `_` after the last character once typing is done.
  final bool cursorAfterDone;
  final Color cursorColor;
  final VoidCallback? onDone;
  final bool liveRegion;
  final TextAlign? textAlign;

  @override
  State<TypingText> createState() => TypingTextState();
}

class TypingTextState extends State<TypingText> with TickerProviderStateMixin {
  // Rebuilds go through AnimatedBuilder (never setState from a listener), so
  // completing from didChangeDependencies is safe.
  late final AnimationController _type = AnimationController(vsync: this)..addStatusListener(_onStatus);
  late final AnimationController _blink = AnimationController(vsync: this, duration: DojiMotion.cursorBlink);
  TypingSkipController? _scope;
  int _scopeGeneration = 0;
  bool _doneNotified = false;
  bool _reduced = false;

  bool get isComplete => _type.value >= 1;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = DojiMotion.reduced(context);
    final scope = TypingScope.maybeOf(context);
    if (!identical(scope, _scope)) {
      _scope = scope;
      _scopeGeneration = scope?.generation ?? 0;
    } else if (scope != null && scope.generation != _scopeGeneration) {
      _scopeGeneration = scope.generation;
      complete();
    }
    if (_reduced && !isComplete) complete();
  }

  @override
  void didUpdateWidget(TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _doneNotified = false;
      _type.value = 0;
      _blink.stop();
      _configure();
    } else if (!oldWidget.start && widget.start && !isComplete) {
      _type.forward();
    }
  }

  void _configure() {
    _type.duration = widget.charDelay * widget.text.length.clamp(1, 100000);
    if (widget.text.isEmpty) {
      _type.value = 1;
    } else if (widget.start) {
      _type.forward();
    }
  }

  /// Finish typing now (tap-to-complete, scope skip, reduce motion).
  void complete() {
    if (!isComplete) _type.value = 1;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.showCursor && widget.cursorAfterDone && !_reduced) {
      _blink.repeat();
    }
    if (!_doneNotified) {
      _doneNotified = true;
      // Defer so parents can setState in response.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone?.call();
      });
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: Listenable.merge([_type, _blink]), builder: (context, _) => _buildLine());

  Widget _buildLine() {
    final text = widget.text;
    final count = (_type.value * text.length).round().clamp(0, text.length);
    final started = widget.start || count > 0;
    final done = count >= text.length && started;
    final typing = started && !done;

    Color cursor = Colors.transparent;
    if (widget.showCursor && started) {
      if (typing) {
        cursor = widget.cursorColor;
      } else if (widget.cursorAfterDone) {
        final on = _reduced || !_blink.isAnimating || _blink.value < 0.5;
        cursor = on ? widget.cursorColor : Colors.transparent;
      }
    }
    final showCursorSpan = widget.showCursor && (typing || widget.cursorAfterDone);

    const hidden = TextStyle(color: Colors.transparent);
    final visual = Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          if (widget.prefix.isNotEmpty)
            TextSpan(
              text: widget.prefix,
              style: started ? TextStyle(color: widget.prefixColor) : hidden,
            ),
          TextSpan(text: text.substring(0, count)),
          if (showCursorSpan)
            TextSpan(
              text: '_',
              style: TextStyle(color: cursor),
            ),
          TextSpan(text: text.substring(count), style: hidden),
        ],
      ),
      textAlign: widget.textAlign,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: typing ? complete : null,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        liveRegion: widget.liveRegion,
        label: text,
        child: ExcludeSemantics(child: visual),
      ),
    );
  }
}

/// A standalone `_` that blinks at 1.1s with a 50% duty cycle.
/// Solid when reduce motion is on.
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key, this.color = DojiColors.dojiGreen, this.style});

  final Color color;
  final TextStyle? style;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: DojiMotion.cursorBlink);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DojiMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Text(
        '_',
        style: (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
          color: !_c.isAnimating || _c.value < 0.5 ? widget.color : Colors.transparent,
        ),
      ),
    ),
  );
}

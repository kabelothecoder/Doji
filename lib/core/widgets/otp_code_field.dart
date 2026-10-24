import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

enum OtpFieldState { idle, wrong, disabled }

/// Design system: `OtpCodeField` (auth component spec, A4 – A4e).
///
/// "Stack › [Row of 6 _OtpBox (64h, radius 10, Geist Mono 28), invisible
/// TextField(keyboardType: number, autofillHints: [oneTimeCode], maxLength: 6,
/// digitsOnly)]". One hidden field drives the boxes, so paste and one-time-code
/// autofill work natively. Paste accepts any string containing 6 digits; typing
/// into a full field starts a new code.
///
/// - active box in doji-green, filled boxes elevated-2
/// - wrong: orange + shake 3 × 6px over 240ms (reduce motion: colour only)
/// - disabled: grey digits, no input
/// - one Semantics node: "6-digit code, 2 of 6 entered"
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = 6,
    this.state = OtpFieldState.idle,
    this.autofocus = false,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final OtpFieldState state;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  /// The first [length] digits in [raw], or null when there aren't enough.
  static String? digitsIn(String? raw, {int length = 6}) {
    final d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    return d.length < length ? null : d.substring(0, length);
  }

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final AnimationController _blink = AnimationController(vsync: this, duration: DojiMotion.cursorBlink);
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());
  String? _completed;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DojiMotion.reduced(context)) {
      _blink.stop();
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void didUpdateWidget(OtpCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (old.state != OtpFieldState.wrong &&
        widget.state == OtpFieldState.wrong &&
        !DojiMotion.reduced(context)) {
      _shake.forward(from: 0);
    }
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final text = widget.controller.text;
    if (text.length < widget.length) _completed = null;
    setState(() {});
  }

  void _changed(String text) {
    widget.onChanged?.call(text);
    if (text.length == widget.length && _completed != text) {
      _completed = text;
      widget.onCompleted?.call(text);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    _own?.dispose();
    _shake.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final disabled = widget.state == OtpFieldState.disabled;
    final wrong = widget.state == OtpFieldState.wrong;
    final reduced = DojiMotion.reduced(context);

    final boxes = AnimatedBuilder(
      animation: Listenable.merge([_shake, _blink]),
      builder: (context, _) {
        final t = _shake.value;
        final dx = _shake.isAnimating ? math.sin(t * 3 * 2 * math.pi) * 6 : 0.0;
        final caretOn = reduced || !_blink.isAnimating || _blink.value < 0.5;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _OtpBox(
                    char: i < text.length ? text[i] : '',
                    active: !disabled && !wrong && _focus.hasFocus && i == text.length,
                    wrong: wrong,
                    disabled: disabled,
                    caretVisible: caretOn,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    final field = TextSelectionTheme(
      data: const TextSelectionThemeData(selectionColor: Colors.transparent),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        enabled: !disabled,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [_CodeFormatter(widget.length)],
        onChanged: _changed,
        showCursor: false,
        autocorrect: false,
        enableSuggestions: false,
        keyboardAppearance: Brightness.dark,
        style: const TextStyle(color: Colors.transparent, fontSize: 16),
        decoration: const InputDecoration.collapsed(hintText: null),
        mouseCursor: SystemMouseCursors.text,
      ),
    );

    return MergeSemantics(
      child: Semantics(
        label: '${widget.length}-digit code, ${text.length} of ${widget.length} entered',
        child: Stack(
          children: [
            ExcludeSemantics(child: boxes),
            Positioned.fill(child: field),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.char,
    required this.active,
    required this.wrong,
    required this.disabled,
    required this.caretVisible,
  });

  final String char;
  final bool active;
  final bool wrong;
  final bool disabled;
  final bool caretVisible;

  @override
  Widget build(BuildContext context) {
    final border = wrong
        ? Border.all(color: DojiColors.tiltOrange, width: 1.5)
        : active
        ? Border.all(color: DojiColors.dojiGreen, width: 1.5)
        : Border.all(color: DojiColors.separator);
    final style = DojiType.data.copyWith(
      fontSize: 28,
      color: disabled ? DojiColors.textSecondary : DojiColors.textPrimary,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: char.isEmpty ? DojiColors.elevated1 : DojiColors.elevated2,
        borderRadius: BorderRadius.circular(DojiRadius.chip),
        border: border,
      ),
      child: char.isNotEmpty
          ? Text(char, style: style)
          : active
          ? Container(width: 2, height: 28, color: caretVisible ? DojiColors.dojiGreen : Colors.transparent)
          : const SizedBox.shrink(),
    );
  }
}

/// Digits only, at most [length]. Typing or pasting into a full field starts
/// over with the new digits.
class _CodeFormatter extends TextInputFormatter {
  _CodeFormatter(this.length);

  final int length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (oldValue.text.length == length && digits.length > length) digits = digits.substring(length);
    if (digits.length > length) digits = digits.substring(0, length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

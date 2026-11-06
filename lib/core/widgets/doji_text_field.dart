import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: text answer — "TextField + InputDecoration(filled, radius 16)".
///
/// 60pt tall, elevated-1 fill, 1px doji-green border when focused, 2px green
/// caret. [errorText] turns the border tilt-orange (the message itself is
/// shown by the caller as a TerminalLine so it reads in doji's voice).
class DojiTextField extends StatefulWidget {
  const DojiTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.autofocus = false,
    this.large = true,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.hasError = false,
    this.semanticLabel,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.trailing,
    this.textStyle,
    this.accent = DojiColors.dojiGreen,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;
  final bool autofocus;

  /// 22/500 answer text (true) or 17 body text (false).
  final bool large;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final String? semanticLabel;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;

  /// Overrides the 22 / 17 answer style (auth email 19, delete-confirm mono).
  final TextStyle? textStyle;

  /// Focused border and caret. Tilt-orange on the delete confirmation.
  final Color accent;
  final bool autocorrect;
  final bool enableSuggestions;

  /// Passwords (the MT5 investor password). Turns off suggestions too.
  final bool obscureText;

  @override
  State<DojiTextField> createState() => _DojiTextFieldState();
}

class _DojiTextFieldState extends State<DojiTextField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.hasError
        ? DojiColors.tiltOrange
        : _focus.hasFocus
        ? widget.accent
        : DojiColors.separator;
    final style = widget.textStyle ?? (widget.large ? DojiType.answer : DojiType.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 60),
          padding: EdgeInsets.fromLTRB(20, 4, widget.trailing == null ? 20 : 8, 4),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  label: widget.semanticLabel,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    style: style,
                    cursorColor: widget.accent,
                    autocorrect: widget.autocorrect,
                    enableSuggestions: widget.enableSuggestions && !widget.obscureText,
                    obscureText: widget.obscureText,
                    cursorWidth: 2,
                    textInputAction: widget.textInputAction,
                    keyboardType: widget.keyboardType,
                    onSubmitted: widget.onSubmitted,
                    onChanged: widget.onChanged,
                    autofillHints: widget.autofillHints,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: widget.inputFormatters,
                    keyboardAppearance: Brightness.dark,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: style.copyWith(color: DojiColors.textSecondary),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: widget.trailing),
              ],
            ],
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 12),
          Text(widget.helper!, style: DojiType.callout),
        ],
      ],
    );
  }
}

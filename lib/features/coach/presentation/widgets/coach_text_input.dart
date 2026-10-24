import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// Text coaching, in push-to-talk's place: on plans without the voice coach,
/// where the device has no dictation (Windows for now), or with the
/// microphone off. Not in the handoff; built from design-system parts.
/// Return sends.
class CoachTextInput extends StatefulWidget {
  const CoachTextInput({super.key, required this.onSend, this.autofocus = false});

  final ValueChanged<String> onSend;
  final bool autofocus;

  @override
  State<CoachTextInput> createState() => _CoachTextInputState();
}

class _CoachTextInputState extends State<CoachTextInput> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final words = _text.text.trim();
    if (words.isEmpty) return;
    widget.onSend(words);
    _text.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => DojiTextField(
    controller: _text,
    focusNode: _focus,
    autofocus: widget.autofocus,
    large: false,
    hint: 'type to your coach',
    semanticLabel: 'message to your coach',
    textInputAction: TextInputAction.send,
    textCapitalization: TextCapitalization.sentences,
    onSubmitted: (_) => _send(),
    trailing: DojiIconButton(
      icon: Icons.arrow_upward_rounded,
      semanticLabel: 'send',
      filled: true,
      background: _text.text.trim().isEmpty ? DojiColors.elevated2 : null,
      foreground: _text.text.trim().isEmpty ? DojiColors.textSecondary : null,
      onPressed: _text.text.trim().isEmpty ? null : _send,
    ),
  );
}

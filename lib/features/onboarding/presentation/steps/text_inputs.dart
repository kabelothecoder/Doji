import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/voice_input.dart';
import '../../domain/onboarding_step.dart';
import '../../domain/strategy_parser.dart';
import 'step_input.dart';

/// Handoff 2a: `TextField(autofocus, textInputAction: next)`.
/// "Keyboard opens on entry; return key submits."
class TextAnswerInput extends StatefulWidget {
  const TextAnswerInput(this.args, {super.key, this.helper});

  final StepInputArgs args;
  final String? helper;

  @override
  State<TextAnswerInput> createState() => _TextAnswerInputState();
}

class _TextAnswerInputState extends State<TextAnswerInput> {
  late final _c = TextEditingController(
    text: widget.args.draft is String ? widget.args.draft! as String : '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DojiTextField(
    controller: _c,
    autofocus: true,
    hasError: widget.args.hasError,
    helper: widget.helper,
    semanticLabel: widget.args.step.prompt,
    textInputAction: TextInputAction.next,
    textCapitalization: TextCapitalization.words,
    autofillHints: const [AutofillHints.nickname],
    onChanged: (v) => widget.args.onChanged(v),
    onSubmitted: (_) => widget.args.onSubmit(),
  );
}

/// Handoff 4a: `TextField(maxLines: 5) · MicButton(speech_to_text) ·
/// ActionChip × 5`. "While parsing, the blinking cursor is the only loading
/// state; no spinner."
class StrategyInput extends ConsumerStatefulWidget {
  const StrategyInput(this.args, {super.key, required this.parsing});

  final StepInputArgs args;
  final bool parsing;

  @override
  ConsumerState<StrategyInput> createState() => _StrategyInputState();
}

enum _Mic { idle, listening, denied, unsupported }

class _StrategyInputState extends ConsumerState<StrategyInput> {
  late final _c = TextEditingController(text: A.mapStr(widget.args.draft, 'raw') ?? '');
  _Mic _mic = _Mic.idle;
  String _beforeDictation = '';

  VoiceInput get _voice => ref.read(voiceInputProvider);

  @override
  void initState() {
    super.initState();
    if (!ref.read(voiceInputProvider).mightBeAvailable) _mic = _Mic.unsupported;
  }

  @override
  void dispose() {
    if (_mic == _Mic.listening) unawaited(_voice.stop());
    _c.dispose();
    super.dispose();
  }

  void _update({String? raw, String? template, bool clearTemplate = false, String? source}) {
    final m = widget.args.draftMap;
    if (raw != null) {
      raw.trim().isEmpty ? m.remove('raw') : m['raw'] = raw.trim();
    }
    if (clearTemplate) m.remove('template');
    if (template != null) m['template'] = template;
    m['source'] = source ?? (m['raw'] != null ? (m['source'] == 'voice' ? 'voice' : 'text') : 'template');
    widget.args.onChanged(m);
  }

  Future<void> _toggleMic() async {
    if (_mic == _Mic.listening) {
      await _voice.stop();
      if (mounted) setState(() => _mic = _Mic.idle);
      return;
    }
    final availability = await _voice.prepare();
    if (!mounted) return;
    if (availability != VoiceAvailability.available) {
      setState(
        () => _mic = availability == VoiceAvailability.permissionDenied ? _Mic.denied : _Mic.unsupported,
      );
      return;
    }
    _beforeDictation = _c.text.trim();
    setState(() => _mic = _Mic.listening);
    await _voice.start(
      onResult: (words, isFinal) {
        if (!mounted) return;
        final text = [_beforeDictation, words].where((s) => s.isNotEmpty).join(' ');
        _c.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _update(raw: text, source: 'voice');
      },
      onStopped: () {
        if (mounted && _mic == _Mic.listening) setState(() => _mic = _Mic.idle);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final template = A.mapStr(args.draft, 'template');
    final status = widget.parsing
        ? ('reading your strategy', TerminalTone.muted)
        : switch (_mic) {
            _Mic.listening => ('listening', TerminalTone.muted),
            _Mic.denied => ('mic is off. typing works too.', TerminalTone.tilt), // doji voice
            _ => (null, TerminalTone.muted),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(
              color: args.hasError
                  ? DojiColors.tiltOrange
                  : _mic == _Mic.listening
                  ? DojiColors.dojiGreen
                  : DojiColors.separator,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _c,
                enabled: !widget.parsing,
                minLines: 3,
                maxLines: 5,
                style: DojiType.body.copyWith(height: 1.45),
                cursorColor: DojiColors.dojiGreen,
                keyboardType: TextInputType.multiline,
                onChanged: (v) => _update(raw: v, source: 'text'),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText:
                      'how you find a setup, where you enter, where the stop goes, what you aim for.', // doji voice
                  hintStyle: DojiType.body.copyWith(color: DojiColors.textSecondary, height: 1.45),
                  hintMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: status.$1 == null
                        ? const SizedBox(height: 20)
                        : TerminalLine(
                            status.$1!,
                            tone: status.$2,
                            cursor: widget.parsing || _mic == _Mic.listening,
                            style: DojiType.hint.copyWith(fontSize: 13, color: DojiColors.dojiGreen),
                          ),
                  ),
                  if (_mic == _Mic.idle || _mic == _Mic.listening)
                    DojiIconButton(
                      icon: Icons.mic_rounded,
                      semanticLabel: _mic == _Mic.listening ? 'Stop dictation' : 'Dictate',
                      filled: _mic == _Mic.listening,
                      onPressed: widget.parsing ? null : _toggleMic,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('OR START FROM A TEMPLATE', style: DojiType.label.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in strategyTemplateLabels.entries)
              DojiChoiceChip(
                style: DojiChoiceStyle.chip,
                label: e.value,
                minHeight: 44,
                selected: template == e.key,
                textStyle: DojiType.callout.copyWith(
                  color: template == e.key ? DojiColors.bg : DojiColors.textPrimary,
                  fontSize: 14,
                ),
                onTap: widget.parsing
                    ? null
                    : () => template == e.key ? _update(clearTemplate: true) : _update(template: e.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Handoff 4b: `ParsedRuleRow(label, value, onEdit) × 5`.
/// "Each row opens an inline editor. Lines stream in one by one."
class ParsedStrategyInput extends StatefulWidget {
  const ParsedStrategyInput(this.args, {super.key});

  final StepInputArgs args;

  static const fields = ['setup', 'timeframe', 'entry', 'stop', 'target'];

  @override
  State<ParsedStrategyInput> createState() => _ParsedStrategyInputState();
}

class _ParsedStrategyInputState extends State<ParsedStrategyInput> {
  int _shown = 0;
  Timer? _stream;
  String? _editing;
  final _edit = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null || _shown > 0) return;
    if (DojiMotion.reduced(context)) {
      _shown = ParsedStrategyInput.fields.length;
    } else {
      _stream = Timer.periodic(const Duration(milliseconds: 110), (t) {
        if (!mounted) return t.cancel();
        setState(() => _shown++);
        if (_shown >= ParsedStrategyInput.fields.length) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _stream?.cancel();
    _edit.dispose();
    super.dispose();
  }

  void _startEdit(String field) {
    _edit.text = A.mapStr(widget.args.draft, field) ?? '';
    setState(() => _editing = field);
  }

  void _commit() {
    final field = _editing;
    if (field == null) return;
    final m = widget.args.draftMap;
    final v = _edit.text.trim();
    v.isEmpty ? m.remove(field) : m[field] = v;
    widget.args.onChanged(m);
    setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    const fields = ParsedStrategyInput.fields;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DojiRadius.card),
      child: ColoredBox(
        color: DojiColors.elevated1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fields.length; i++)
              AnimatedOpacity(
                opacity: i < _shown ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: _row(fields[i], i),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String field, int i) {
    final value = A.mapStr(widget.args.draft, field);
    final editing = _editing == field;
    final divider = i == 0 ? null : const Border(top: BorderSide(color: DojiColors.divider));
    final content = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: divider),
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(field, style: DojiType.hint)),
          const SizedBox(width: 10),
          Expanded(
            child: editing
                ? TextField(
                    controller: _edit,
                    autofocus: true,
                    style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                    cursorColor: DojiColors.dojiGreen,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _commit(),
                    onTapOutside: (_) => _commit(),
                    decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
                  )
                : Text(
                    value ?? 'not stated yet — tap to add', // doji voice
                    style: DojiType.callout.copyWith(
                      color: value == null ? DojiColors.textSecondary : DojiColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Icon(
            editing ? Icons.check_rounded : Icons.edit_outlined,
            size: 18,
            color: editing ? DojiColors.dojiGreen : DojiColors.textSecondary,
          ),
        ],
      ),
    );
    if (editing) return content;
    return DojiPressable(
      onPressed: () => _startEdit(field),
      semanticLabel: 'edit $field: ${value ?? 'not stated'}',
      pressedScale: 1,
      child: content,
    );
  }
}

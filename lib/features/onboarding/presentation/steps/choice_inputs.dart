import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/onboarding_catalog.dart';
import '../../domain/onboarding_step.dart';
import '../../domain/sessions.dart';
import 'step_input.dart';

/// Handoff `DojiChoiceGrid(single, columns: 2)`: experience, style.
class SingleChoiceInput extends StatelessWidget {
  const SingleChoiceInput(this.args, {super.key});

  final StepInputArgs args;

  @override
  Widget build(BuildContext context) {
    final options = args.step.resolveOptions(args.answers);
    final cols = args.wide && options.length <= 4 ? options.length : args.step.columns;
    return EqualColumns(
      columns: cols,
      gap: args.wide ? 10 : 8,
      children: [
        for (var i = 0; i < options.length; i++)
          DojiChoiceChip(
            label: options[i].label,
            mono: options[i].mono,
            selected: args.draft == options[i].value,
            exclusive: true,
            keyHint: '${i + 1}',
            minHeight: args.wide ? 60 : 56,
            onTap: () => args.onChanged(options[i].value, advance: args.step.autoAdvance),
          ),
      ],
    );
  }
}

/// Handoff `Wrap › FilterChip × n`: markets (with search + custom), sessions
/// (with the detected time zone), struggles.
class MultiChoiceInput extends StatefulWidget {
  const MultiChoiceInput(this.args, {super.key, this.onChangeTimeZone});

  final StepInputArgs args;
  final VoidCallback? onChangeTimeZone;

  @override
  State<MultiChoiceInput> createState() => _MultiChoiceInputState();
}

class _MultiChoiceInputState extends State<MultiChoiceInput> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  bool get _isMarkets => widget.args.step.id == StepIds.markets;
  bool get _isSessions => widget.args.step.id == StepIds.sessions;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    final list = widget.args.draftList;
    list.contains(value) ? list.remove(value) : list.add(value);
    widget.args.onChanged(list);
  }

  static final _symbolPattern = RegExp(r'^[A-Z0-9/.\-]{2,12}$');

  bool _matches(StepOption o, String q) {
    if (q.isEmpty) return true;
    final aliases = marketAliases[o.value] ?? const [];
    return o.value.contains(q) || aliases.any((a) => a.contains(q));
  }

  void _addCustom() {
    final q = _search.text.trim().toUpperCase();
    if (!_symbolPattern.hasMatch(q)) return;
    final list = widget.args.draftList;
    if (!list.contains(q)) widget.args.onChanged([...list, q]);
    _search.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final selected = args.draftList;
    final q = _search.text.trim().toUpperCase();
    final base = args.step.resolveOptions(args.answers);
    final custom = [
      for (final s in selected)
        if (!base.any((o) => o.value == s)) StepOption(s, s, mono: true),
    ];
    final options = [...base.where((o) => _matches(o, q)), ...custom];
    final exact = base.any((o) => o.value == q || (marketAliases[o.value] ?? const []).contains(q));
    final canAdd = _isMarkets && q.isNotEmpty && !exact && _symbolPattern.hasMatch(q);
    final r = BorderRadius.circular(DojiChoiceChip.radiusFor(Theme.of(context).platform));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isMarkets) ...[
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: DojiColors.elevated1,
              borderRadius: r,
              border: Border.all(color: _searchFocus.hasFocus ? DojiColors.dojiGreen : DojiColors.separator),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: DojiColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    style: DojiType.terminal.copyWith(color: DojiColors.textPrimary),
                    cursorColor: DojiColors.dojiGreen,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onTap: () => setState(() {}),
                    onSubmitted: (_) => _addCustom(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: 'search or add a symbol',
                      hintStyle: DojiType.terminal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              DojiChoiceChip(
                style: DojiChoiceStyle.chip,
                label: options[i].label,
                mono: options[i].mono,
                selected: selected.contains(options[i].value),
                // Number keys map to the unfiltered list, so hide hints while searching.
                keyHint: q.isEmpty && i < 9 ? '${i + 1}' : null,
                onTap: () => _toggle(options[i].value),
              ),
            if (canAdd)
              DojiChoiceChip(
                style: DojiChoiceStyle.chip,
                label: '+ add $q',
                mono: true,
                dashed: true,
                selected: false,
                onTap: _addCustom,
              )
            else if (_isMarkets)
              DojiChoiceChip(
                style: DojiChoiceStyle.chip,
                label: '+ custom',
                dashed: true,
                selected: false,
                onTap: () => _searchFocus.requestFocus(),
              ),
          ],
        ),
        if (_isSessions) ...[
          const SizedBox(height: 12),
          _TimeZoneRow(answers: args.answers, onChange: widget.onChangeTimeZone),
        ],
      ],
    );
  }
}

class _TimeZoneRow extends StatelessWidget {
  const _TimeZoneRow({required this.answers, this.onChange});

  final Answers answers;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final tz = answers[StepIds.timeZone];
    final id = A.mapStr(tz, 'id');
    final offset = A.mapNum(tz, 'offsetMinutes')?.round();
    final detected = tz is Map && tz['detected'] != false;
    final label = id == null
        ? 'DETECTING TIME ZONE…'
        : '${id.toUpperCase()} · ${utcLabel(offset ?? 0)} · ${detected ? 'DETECTED' : 'SET BY YOU'}';
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: DojiColors.dojiGreen),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: DojiType.hint)),
        if (onChange != null)
          DojiButton(
            label: 'change',
            variant: DojiButtonVariant.ghost,
            size: DojiButtonSize.small,
            expand: false,
            semanticLabel: 'change time zone',
            onPressed: onChange,
          ),
      ],
    );
  }
}

/// Handoff 3a: `DojiChoiceList · AnimatedSize › PropDetails`.
/// Prop firm and size appear only when the goal is a prop challenge.
class GoalInput extends StatefulWidget {
  const GoalInput(this.args, {super.key});

  final StepInputArgs args;

  @override
  State<GoalInput> createState() => _GoalInputState();
}

class _GoalInputState extends State<GoalInput> {
  late final _firm = TextEditingController(text: A.mapStr(widget.args.draft, 'propFirm') ?? '');

  @override
  void dispose() {
    _firm.dispose();
    super.dispose();
  }

  void _set(String key, Object? value) {
    final m = widget.args.draftMap;
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    widget.args.onChanged(m);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final goal = A.mapStr(args.draft, 'goal');
    final size = A.mapNum(args.draft, 'propSize')?.round();
    final isProp = goal == 'prop_challenge';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EqualColumns(
          columns: args.wide ? 2 : 1,
          children: [
            for (var i = 0; i < goalOptions.length; i++)
              DojiChoiceChip(
                label: goalOptions[i].label,
                selected: goal == goalOptions[i].value,
                exclusive: true,
                keyHint: '${i + 1}',
                minHeight: 48,
                onTap: () => _set('goal', goalOptions[i].value),
              ),
          ],
        ),
        DojiAnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: DojiMotion.sheet,
          child: !isProp
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DojiColors.elevated1,
                      borderRadius: BorderRadius.circular(DojiRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('PROP · OPTIONAL', style: DojiType.label.copyWith(letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 44),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: DojiColors.elevated2,
                                  borderRadius: BorderRadius.circular(DojiRadius.chip),
                                ),
                                child: TextField(
                                  controller: _firm,
                                  style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                                  cursorColor: DojiColors.dojiGreen,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (v) => _set('propFirm', v.trim().isEmpty ? null : v.trim()),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: 'firm name',
                                    hintStyle: DojiType.callout,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < propSizes.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: DojiChoiceChip(
                                  label: '${propSizes[i] ~/ 1000}k',
                                  mono: true,
                                  center: true,
                                  exclusive: true,
                                  minHeight: 44,
                                  textStyle: DojiType.hint.copyWith(fontSize: 13),
                                  selected: size == propSizes[i],
                                  onTap: () => _set('propSize', size == propSizes[i] ? null : propSizes[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

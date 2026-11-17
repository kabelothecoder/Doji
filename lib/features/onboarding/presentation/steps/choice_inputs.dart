import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../markets/domain/instrument.dart';
import '../../../markets/domain/instrument_catalog.dart';
import '../../domain/onboarding_catalog.dart';
import '../../domain/onboarding_step.dart';
import '../../domain/prop_rules.dart';
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

  /// Markets only: one group at a time, or null for all of them.
  InstrumentGroup? _group;

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

  bool _matches(StepOption o, String q) => instrumentMatches(o.value, q);

  void _addCustom() {
    final q = _search.text.trim().toUpperCase();
    if (!_symbolPattern.hasMatch(q)) return;
    final list = widget.args.draftList;
    if (!list.contains(q)) widget.args.onChanged([...list, q]);
    _search.clear();
    setState(() {});
  }

  Widget _chip(List<StepOption> options, int i, List<String> selected, String q) => DojiChoiceChip(
    style: DojiChoiceStyle.chip,
    label: options[i].label,
    mono: options[i].mono,
    selected: selected.contains(options[i].value),
    // Number keys map to the unfiltered list, so hide hints while searching.
    keyHint: q.isEmpty && _group == null && i < 9 ? '${i + 1}' : null,
    onTap: () => _toggle(options[i].value),
  );

  /// "+ add SYMBOL" while typing an unknown symbol, otherwise "+ custom".
  List<Widget> _tailChips(bool canAdd, String q) => [
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
  ];

  /// Instruments under their group's heading (forex, metals, indices, oil,
  /// crypto, volatility indices, boom and crash), then the user's own symbols.
  List<Widget> _groupedMarkets(
    List<StepOption> options,
    List<String> selected, {
    required bool canAdd,
    required String q,
  }) {
    final widgets = <Widget>[];
    InstrumentGroup? group;
    var run = <Widget>[];
    void flush() {
      if (run.isEmpty) return;
      widgets.add(Wrap(spacing: 8, runSpacing: 8, children: run));
      run = [];
    }

    for (var i = 0; i < options.length; i++) {
      final g = instrumentBySymbol(options[i].value)?.group;
      if (widgets.isEmpty || g != group) {
        flush();
        group = g;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 16, bottom: 8),
            child: Semantics(
              header: true,
              child: Text((g?.label ?? 'your own').toUpperCase(), style: DojiType.label),
            ),
          ),
        );
      }
      run.add(_chip(options, i, selected, q));
    }
    run.addAll(_tailChips(canAdd, q));
    flush();
    return widgets;
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
    final groups = _isMarkets
        ? {for (final o in base) ?instrumentBySymbol(o.value)?.group}.toList()
        : const <InstrumentGroup>[];
    bool inGroup(StepOption o) =>
        _group == null || q.isNotEmpty || instrumentBySymbol(o.value)?.group == _group;
    final options = [
      ...base.where((o) => _matches(o, q) && inGroup(o)),
      if (_group == null || q.isNotEmpty) ...custom,
    ];
    final exact = base.any((o) => instrumentIsExact(o.value, q));
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
                    inputFormatters: [LengthLimitingTextInputFormatter(24)],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onTap: () => setState(() {}),
                    onSubmitted: (_) => _addCustom(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: 'search or add an instrument',
                      hintStyle: DojiType.terminal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (q.isEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final g in <InstrumentGroup?>[null, ...groups]) ...[
                    DojiChoiceChip(
                      style: DojiChoiceStyle.chip,
                      label: g?.label ?? 'all',
                      exclusive: true,
                      selected: _group == g,
                      onTap: () => setState(() => _group = g),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (selected.isNotEmpty) ...[
            Text(
              '${selected.length} picked: ${selected.map((v) => instrumentBySymbol(v)?.displayLabel ?? v).join(', ')}',
              style: DojiType.hint,
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (_isMarkets && q.isEmpty)
          ..._groupedMarkets(options, selected, canAdd: canAdd, q: q)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++) _chip(options, i, selected, q),
              ..._tailChips(canAdd, q),
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
  late final _daily = TextEditingController(text: _pctText('propDailyLoss'));
  late final _drawdown = TextEditingController(text: _pctText('propMaxDrawdown'));
  late final _target = TextEditingController(text: _pctText('propTarget'));

  String _pctText(String key) {
    final v = A.mapNum(widget.args.draft, key);
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  void dispose() {
    _firm.dispose();
    _daily.dispose();
    _drawdown.dispose();
    _target.dispose();
    super.dispose();
  }

  /// A percentage of the account: anything outside 0–100 is ignored.
  void _setPct(String key, String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    _set(key, v != null && v > 0 && v <= 100 ? v : null);
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
    final drawdownType =
        DrawdownType.values.asNameMap()[A.mapStr(args.draft, 'propDrawdownType')] ?? DrawdownType.fixed;
    final trailingBasis =
        TrailingBasis.values.asNameMap()[A.mapStr(args.draft, 'propTrailingBasis')] ?? TrailingBasis.equity;
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
                        const SizedBox(height: 8),
                        // The challenge's own limits, % of the account. Optional.
                        EqualColumns(
                          columns: 3,
                          gap: 6,
                          children: [
                            _PctField(
                              label: 'daily loss %',
                              controller: _daily,
                              onChanged: (v) => _setPct('propDailyLoss', v),
                            ),
                            _PctField(
                              label: 'max drawdown %',
                              controller: _drawdown,
                              onChanged: (v) => _setPct('propMaxDrawdown', v),
                            ),
                            _PctField(
                              label: 'profit target %',
                              controller: _target,
                              onChanged: (v) => _setPct('propTarget', v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // How the firm measures the drawdown; warnings follow this choice.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in DrawdownType.values)
                              DojiChoiceChip(
                                style: DojiChoiceStyle.chip,
                                label: '${t.label} drawdown',
                                exclusive: true,
                                selected: drawdownType == t,
                                onTap: () => _set('propDrawdownType', t.name),
                              ),
                            if (drawdownType == DrawdownType.trailing)
                              for (final b in TrailingBasis.values)
                                DojiChoiceChip(
                                  style: DojiChoiceStyle.chip,
                                  label: 'follows ${b.name}',
                                  exclusive: true,
                                  selected: trailingBasis == b,
                                  onTap: () => _set('propTrailingBasis', b.name),
                                ),
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

/// One prop limit, typed as a percent of the account.
class _PctField extends StatelessWidget {
  const _PctField({required this.label, required this.controller, required this.onChanged});

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: DojiType.hint),
      const SizedBox(height: 4),
      Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: DojiColors.elevated2,
          borderRadius: BorderRadius.circular(DojiRadius.chip),
        ),
        child: Semantics(
          textField: true,
          label: label,
          child: TextField(
            controller: controller,
            style: DojiType.data.copyWith(fontSize: 15),
            cursorColor: DojiColors.dojiGreen,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(5),
            ],
            textInputAction: TextInputAction.next,
            onChanged: onChanged,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: '–',
              hintStyle: DojiType.callout,
            ),
          ),
        ),
      ),
    ],
  );
}

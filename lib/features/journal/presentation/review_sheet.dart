import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/formatting.dart';
import '../domain/journal_stats.dart';
import '../domain/process_grade.dart';
import '../domain/trade.dart';
import 'journal_controller.dart';
import 'widgets/emotion_tag.dart';
import 'widgets/journal_segmented.dart';
import 'widgets/mistake_tag_chip.dart';
import 'widgets/process_grade_box.dart';

/// The post-trade review (Doji Trade Journal › ReviewSheet): setup, was the
/// plan followed, mistake tags, emotion before and after, one line. The grade
/// updates as you tap. Saved on this device.
Future<void> showReviewSheet(BuildContext context, Trade trade) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (_) => ReviewSheet(trade: trade),
  );
}

class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key, required this.trade});

  final Trade trade;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  late String? _setup = widget.trade.setup;
  late PlanFollowed? _plan = widget.trade.plan;
  late final Set<String> _mistakes = {...widget.trade.mistakes};
  late TradeEmotion? _before = widget.trade.before;
  late TradeEmotion? _after = widget.trade.after;
  late final TextEditingController _note = TextEditingController(text: widget.trade.note);
  final _custom = TextEditingController();
  final List<String> _extraSetups = [];
  bool _addingSetup = false;

  @override
  void dispose() {
    _note.dispose();
    _custom.dispose();
    super.dispose();
  }

  /// Parsed strategy setup, setups used before, the trade's own, then "no setup".
  List<String> _setupOptions() {
    final profile = ref.read(journalProfileProvider);
    final used = ref.read(journalControllerProvider).map((t) => t.setup);
    final seen = <String>{};
    return [
      for (final s in [profile.strategy?.parsed?.setup, ...used, widget.trade.setup, ..._extraSetups])
        if (s != null && s.trim().isNotEmpty && s != kNoSetup && seen.add(s.trim())) s.trim(),
      kNoSetup,
    ];
  }

  ProcessGrade? get _grade {
    final plan = _plan;
    if (plan == null || _setup == null) return null;
    return ProcessGrade.of(plan: plan, mistakes: _mistakes.toList(), setup: _setup);
  }

  bool get _canSave => _setup != null && _plan != null;

  void _addSetup() {
    final name = _custom.text.trim().toLowerCase();
    if (name.isEmpty) return;
    setState(() {
      _extraSetups.add(name);
      _setup = name;
      _addingSetup = false;
      _custom.clear();
    });
  }

  void _save() {
    if (!_canSave) return;
    unawaited(ref.read(hapticsProvider).light());
    unawaited(
      ref
          .read(journalControllerProvider.notifier)
          .review(
            widget.trade.id,
            TradeReview(
              setup: _setup!,
              plan: _plan!,
              mistakes: [
                for (final t in kMistakeTags)
                  if (_mistakes.contains(t)) t,
              ],
              before: _before,
              after: _after,
              note: _note.text.trim(),
            ),
          ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final symbol = ref.watch(accountCurrencyProvider).symbol;
    final grade = _grade;
    final options = _setupOptions();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'trade review',
            child: GlassSurface(
              radius: DojiRadius.sheet,
              tint: DojiColors.elevated2,
              fillOpacity: 0.9,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3D42),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TerminalLine(
                              'trade saved · ${instrumentLabel(t.symbol)} ${t.direction.label} · '
                              '${tradeResult(t, ResultUnit.r, symbol)}',
                              liveRegion: false,
                              style: DojiType.hint,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(10, 0),
                            child: DojiIconButton(
                              icon: Icons.close_rounded,
                              semanticLabel: 'close',
                              outlined: false,
                              background: Colors.transparent,
                              foreground: DojiColors.textSecondary,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text('how did it go?', style: DojiType.title.copyWith(fontSize: 24)),
                            ),
                          ),
                          ProcessGradeBox(grade: grade, size: 44, caption: 'grade'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'about the process, not the result. a losing trade that kept the plan is a good trade.',
                        style: DojiType.callout.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const _Section('SETUP'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in options)
                            DojiChoiceChip(
                              label: s,
                              selected: _setup == s,
                              exclusive: true,
                              style: DojiChoiceStyle.chip,
                              onTap: () => setState(() => _setup = s),
                            ),
                          DojiChoiceChip(
                            label: '+ other',
                            selected: false,
                            dashed: true,
                            style: DojiChoiceStyle.chip,
                            onTap: () => setState(() => _addingSetup = !_addingSetup),
                          ),
                        ],
                      ),
                      if (_addingSetup) ...[
                        const SizedBox(height: 10),
                        DojiTextField(
                          controller: _custom,
                          large: false,
                          hint: 'name your setup',
                          semanticLabel: 'new setup name',
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSetup(),
                          trailing: DojiIconButton(
                            icon: Icons.check_rounded,
                            semanticLabel: 'add setup',
                            onPressed: _addSetup,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _Section('DID YOU FOLLOW THE PLAN?'),
                      JournalSegmented<PlanFollowed?>(
                        values: const [PlanFollowed.yes, PlanFollowed.partly, PlanFollowed.no],
                        selected: _plan,
                        groupLabel: 'followed the plan',
                        labelOf: (p) => p!.name,
                        semanticOf: (p) => 'plan followed: ${p!.name}',
                        onChanged: (p) => setState(() => _plan = p),
                      ),
                      const SizedBox(height: 16),
                      _Section('MISTAKES · ${_mistakes.isEmpty ? 'none' : '${_mistakes.length} selected'}'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in kMistakeTags)
                            MistakeTagChip(
                              tag: tag,
                              selected: _mistakes.contains(tag),
                              onTap: () => setState(() {
                                if (!_mistakes.remove(tag)) _mistakes.add(tag);
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _Section('HOW DID YOU FEEL?'),
                      _EmotionPicker(
                        when: 'before the trade',
                        value: _before,
                        onChanged: (e) => setState(() => _before = e),
                      ),
                      const SizedBox(height: 12),
                      _EmotionPicker(
                        when: 'after the trade',
                        value: _after,
                        onChanged: (e) => setState(() => _after = e),
                      ),
                      if (_before != null || _after != null) ...[
                        const SizedBox(height: 12),
                        EmotionTag(before: _before, after: _after),
                      ],
                      const SizedBox(height: 16),
                      const _Section('ONE LINE'),
                      DojiTextField(
                        controller: _note,
                        large: false,
                        hint: "what's the one thing to remember?",
                        semanticLabel: 'note',
                        maxLines: 3,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 16),
                      DojiButton(label: 'save review', onPressed: _canSave ? _save : null),
                      DojiButton(
                        label: 'later',
                        variant: DojiButtonVariant.text,
                        size: DojiButtonSize.small,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(header: true, child: Text(text, style: DojiType.label.copyWith(fontSize: 11))),
  );
}

/// Eight emotions, tap again to clear; the intensity slider appears once one is
/// picked. Optional: no emotion picked means none is saved.
class _EmotionPicker extends StatelessWidget {
  const _EmotionPicker({required this.when, required this.value, required this.onChanged});

  final String when;
  final TradeEmotion? value;
  final ValueChanged<TradeEmotion?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(when, style: DojiType.callout.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kJournalEmotions)
              DojiChoiceChip(
                label: e,
                selected: v?.name == e,
                style: DojiChoiceStyle.chip,
                onTap: () => onChanged(v?.name == e ? null : TradeEmotion(e, v?.intensity ?? 5)),
              ),
          ],
        ),
        if (v != null) ...[
          const SizedBox(height: 8),
          DojiSlider(
            label: '$when · intensity',
            value: v.intensity.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            format: (x) => '${x.round()}/10',
            onChanged: (x) => onChanged(TradeEmotion(v.name, x.round())),
          ),
        ],
      ],
    );
  }
}

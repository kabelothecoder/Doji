import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/widgets/home_card.dart';
import '../../journal/domain/formatting.dart';
import '../../journal/presentation/widgets/journal_page.dart';
import '../../journal/presentation/widgets/journal_segmented.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';

/// Mood (journal tab, no drawn screens in Doji Trade Journal Phone): a
/// check-in, the emotion tracker (every logged feeling, newest first) and
/// trends. Built from design-system parts; colour is never the only signal and
/// no price colours are used: bars are neutral grey with the count in words.
class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

enum _Range {
  week('7 days', 7),
  month('28 days', 28);

  const _Range(this.label, this.days);

  final String label;
  final int days;
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  String? _feeling;
  double _intensity = 5;
  final _note = TextEditingController();
  _Range _range = _Range.week;
  bool _saved = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final feeling = _feeling;
    if (feeling == null) return;
    unawaited(ref.read(hapticsProvider).light());
    await ref
        .read(moodControllerProvider.notifier)
        .log(feeling: feeling, moment: MoodMoment.checkIn, intensity: _intensity.round(), note: _note.text);
    if (!mounted) return;
    _note.clear();
    setState(() {
      _feeling = null;
      _intensity = 5;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(activeMoodProvider);
    final trends = ref.watch(moodTrendsProvider);
    final counts = _range == _Range.week ? trends.week : trends.month;
    return JournalPage(
      children: [
        JournalBackBar(
          label: 'journal',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.journal),
        ),
        Semantics(header: true, child: Text('mood', style: DojiType.title)),
        // Check-in.
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Eyebrow('CHECK IN'),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text('how do you feel right now?', style: DojiType.headline.copyWith(fontSize: 20)),
              ),
              const SizedBox(height: 12),
              FeelingChips(
                selected: _feeling,
                onPick: (f) => setState(() {
                  _feeling = f;
                  _saved = false;
                }),
              ),
              const SizedBox(height: 14),
              DojiSlider(
                label: 'intensity',
                value: _intensity,
                min: 1,
                max: 10,
                divisions: 9,
                format: (v) => '${v.round()}/10',
                onChanged: (v) => setState(() => _intensity = v),
              ),
              const SizedBox(height: 12),
              DojiTextField(
                controller: _note,
                hint: 'one line, if you want',
                semanticLabel: 'note',
                large: false,
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 14),
              DojiButton(label: 'log it', onPressed: _feeling == null ? null : _save),
              if (_saved) ...[
                const SizedBox(height: 8),
                const TerminalLine('logged. noticing it is the skill.'),
              ],
            ],
          ),
        ),
        // Trends.
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Eyebrow('TRENDS'),
              const SizedBox(height: 10),
              JournalSegmented<_Range>(
                values: _Range.values,
                selected: _range,
                groupLabel: 'range',
                labelOf: (r) => r.label,
                semanticOf: (r) => 'last ${r.label}',
                onChanged: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: 12),
              _CountList(title: 'last ${_range.label}', counts: counts),
              const SizedBox(height: 16),
              Text('around losing trades', style: DojiType.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'logged in the hour before a losing trade opened, and in the hour after one closed. last 28 days.',
                style: DojiType.callout.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              _CountList(title: 'before a loss', counts: trends.beforeLoss),
              const SizedBox(height: 12),
              _CountList(title: 'after a loss', counts: trends.afterLoss),
            ],
          ),
        ),
        // Tracker.
        const _Eyebrow('LOGGED'),
        if (entries.isEmpty)
          Text('nothing logged yet. a check-in takes ten seconds.', style: DojiType.callout)
        else
          for (final e in entries.take(30)) _EntryRow(entry: e),
      ],
    );
  }
}

/// The feelings as chips; one can be picked.
class FeelingChips extends StatelessWidget {
  const FeelingChips({super.key, required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final f in kMoodFeelings)
        // The chip centres its label, which would stretch it across a Wrap.
        IntrinsicWidth(
          child: DojiChoiceChip(
            label: f,
            selected: selected == f,
            exclusive: true,
            style: DojiChoiceStyle.chip,
            onTap: () => onPick(f),
          ),
        ),
    ],
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: DojiType.label.copyWith(fontSize: 11));
}

/// Counts per feeling: the word, the count, a neutral bar. Under five entries
/// it says "small sample".
class _CountList extends StatelessWidget {
  const _CountList({required this.title, required this.counts});

  final String title;
  final FeelingCounts counts;

  @override
  Widget build(BuildContext context) {
    final top = counts.counts.isEmpty ? 1 : counts.counts.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            Text(title, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
            Text(
              '${counts.total} ${counts.total == 1 ? 'entry' : 'entries'}${counts.smallSample ? ' · small sample' : ''}',
              style: DojiType.hint.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (counts.total == 0)
          Text('none yet', style: DojiType.hint.copyWith(fontSize: 12))
        else
          for (final (f, n) in counts.counts)
            Semantics(
              label: '$f, $n',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(f, style: DojiType.callout.copyWith(fontSize: 14))),
                    Expanded(
                      flex: 3,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: n / top,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: DojiColors.textSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$n', style: DojiType.data.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// One logged feeling: "anxious 7 · after a trade", when, and the note.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final local = entry.time.toLocal();
    final head = [
      entry.intensity == null ? entry.feeling : '${entry.feeling} ${entry.intensity}',
      entry.moment.label,
      if (entry.tradeId != null) 'on a trade',
    ].join(' · ');
    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DojiColors.elevated2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: DojiType.body.copyWith(fontSize: 15)),
          Text('${dayLabel(local)} · ${clockLabel(local)}', style: DojiType.hint.copyWith(fontSize: 12)),
          if (entry.note.isNotEmpty) Text(entry.note, style: DojiType.callout.copyWith(fontSize: 14)),
        ],
      ),
    );
    final id = entry.tradeId;
    if (id == null) return row;
    return DojiPressable(
      onPressed: () => unawaited(context.push(Routes.tradeDetail(id))),
      semanticLabel: '$head, open the trade',
      child: row,
    );
  }
}

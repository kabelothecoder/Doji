import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/widgets/home_card.dart';
import '../../chart/data/chart_note_repository.dart';
import '../../chart/domain/chart_note.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/formatting.dart';
import '../domain/journal_stats.dart';
import '../domain/process_grade.dart';
import '../domain/trade.dart';
import '../domain/trade_filter.dart';
import '../domain/trade_math.dart';
import 'journal_controller.dart';
import 'review_sheet.dart';
import 'widgets/dashed_border.dart';
import 'widgets/emotion_tag.dart';
import 'widgets/journal_page.dart';
import 'widgets/mistake_tag_chip.dart';
import 'widgets/plan_vs_actual.dart';
import 'widgets/process_grade_box.dart';
import 'widgets/trade_row.dart';

/// One trade: result, process grade, plan vs actual, the review (Doji Trade
/// Journal › trade). The replay chart is a placeholder until its own slice.
class TradeDetailScreen extends ConsumerStatefulWidget {
  const TradeDetailScreen({super.key, required this.tradeId, this.openReview = false});

  final String tradeId;

  /// Open the review sheet as soon as the screen is up (right after adding a trade).
  final bool openReview;

  @override
  ConsumerState<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends ConsumerState<TradeDetailScreen> {
  bool _confirmDelete = false;

  @override
  void initState() {
    super.initState();
    if (widget.openReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final t = _find();
        if (mounted && t != null) unawaited(showReviewSheet(context, t));
      });
    }
  }

  Trade? _find() => ref.read(journalControllerProvider).where((t) => t.id == widget.tradeId).firstOrNull;

  void _back() => context.canPop() ? context.pop() : context.go(Routes.journal);

  @override
  Widget build(BuildContext context) {
    final trade = ref.watch(
      journalControllerProvider.select((l) => l.where((t) => t.id == widget.tradeId).firstOrNull),
    );
    final unit = ref.watch(journalViewProvider.select((v) => v.unit));
    final symbol = ref.watch(accountCurrencyProvider).symbol;
    final profile = ref.watch(journalProfileProvider);

    if (trade == null) {
      return JournalPage(
        children: [
          JournalBackBar(label: 'journal', onBack: _back),
          const TerminalLine('this trade is not in your journal.', liveRegion: false),
        ],
      );
    }

    final t = trade;
    final instrument = instrumentBySymbol(t.symbol);
    final decimals = TradeMath.decimals(instrument);
    final grade = t.grade;
    final session = sessionOf(t.openedAt);
    final r = t.r;
    final primary = tradeResult(t, unit, symbol);
    final secondary = r == null ? null : (unit == ResultUnit.r ? formatMoney(t.pnl, symbol) : formatR(r));
    final moved = t.mistakes.contains('moved stop');
    final early = t.mistakes.contains('early exit');
    final lateEntry = t.mistakes.contains('late entry');
    final planR = (t.stop != null && t.target != null && t.stop != t.entry)
        ? (t.target! - t.entry) * t.direction.sign / (t.entry - t.stop!).abs()
        : null;

    return JournalPage(
      children: [
        JournalBackBar(
          label: 'journal',
          onBack: _back,
          trailing: t.reviewed
              ? JournalPillButton(
                  label: 'edit review',
                  onPressed: () => unawaited(showReviewSheet(context, t)),
                )
              : null,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${whenLabel(t.closedAt)} · $session · ${t.setup ?? 'not reviewed'}',
                    style: DojiType.hint.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 10,
                      children: [
                        Text(
                          instrumentLabel(t.symbol),
                          style: DojiType.title.copyWith(fontFamily: DojiFonts.mono),
                        ),
                        Text(t.direction.label, style: DojiType.callout.copyWith(fontSize: 17)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(primary, style: DojiType.data.copyWith(fontSize: 22, color: resultColor(t.pnl))),
                  if (secondary != null) Text(secondary, style: DojiType.hint.copyWith(fontSize: 13)),
                  if (r == null) ...[
                    const SizedBox(height: 4),
                    Text('no stop, so no R for this trade.', style: DojiType.hint.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ProcessGradeBox(grade: grade, size: 64, caption: 'process'),
          ],
        ),
        if (!t.reviewed)
          HomeCard(
            borderColor: DojiColors.dojiGreen.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TerminalLine('not reviewed yet', liveRegion: false, cursor: true),
                const SizedBox(height: 6),
                Text(
                  'set the setup, say if you followed the plan, and the trade gets a process grade.',
                  style: DojiType.callout.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 12),
                DojiButton(
                  label: 'review · 20 sec',
                  size: DojiButtonSize.regular,
                  onPressed: () => unawaited(showReviewSheet(context, t)),
                ),
              ],
            ),
          ),
        const _ReplayPlaceholder(),
        PlanVsActual(
          rows: [
            PlanRow(
              'entry',
              plan: formatPrice(t.entry, decimals),
              actual: formatPrice(t.entry, decimals),
              kept: t.reviewed ? !lateEntry : null,
            ),
            PlanRow(
              'stop',
              plan: t.stop == null ? '—' : formatPrice(t.stop!, decimals),
              actual: t.stop == null ? '—' : (moved ? 'moved' : formatPrice(t.stop!, decimals)),
              kept: t.reviewed && t.stop != null ? !moved : null,
            ),
            PlanRow(
              'target',
              plan: t.target == null ? '—' : formatPrice(t.target!, decimals),
              actual: early ? 'closed at ${formatPrice(t.exit, decimals)}' : formatPrice(t.exit, decimals),
              kept: t.reviewed && t.target != null ? !early : null,
            ),
            PlanRow('result', plan: planR == null ? '—' : formatR(planR), actual: primary),
            PlanRow('time in trade', plan: '—', actual: durationLabel(t.timeInTrade)),
          ],
        ),
        if (t.reviewed && grade != null)
          _GradeReasons(trade: t, grade: grade, riskPercent: profile.rules?.riskPerTrade),
        if (t.reviewed) _ReviewBlock(trade: t),
        _ChartNotes(tradeId: t.id, decimals: decimals),
        _DeleteRow(
          confirming: _confirmDelete,
          onAsk: () => setState(() => _confirmDelete = true),
          onKeep: () => setState(() => _confirmDelete = false),
          onDelete: () {
            unawaited(ref.read(journalControllerProvider.notifier).remove(t.id));
            _back();
          },
        ),
      ],
    );
  }
}

/// TODO(next-slice): the replay chart (candles, entry and exit markers, stop
/// and target lines) once a price feed exists.
class _ReplayPlaceholder extends StatelessWidget {
  const _ReplayPlaceholder();

  @override
  Widget build(BuildContext context) => DashedBorder(
    radius: DojiRadius.card,
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REPLAY', style: DojiType.label.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          const TerminalLine('replay arrives in a later build.', liveRegion: false),
        ],
      ),
    ),
  );
}

class _GradeReasons extends StatelessWidget {
  const _GradeReasons({required this.trade, required this.grade, required this.riskPercent});

  final Trade trade;
  final ProcessGrade grade;
  final double? riskPercent;

  @override
  Widget build(BuildContext context) {
    final reasons = processReasons(setup: trade.setup, mistakes: trade.mistakes, riskPercent: riskPercent);
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'PROCESS GRADE · ${grade.letter}',
                    style: DojiType.label.copyWith(fontSize: 11),
                  ),
                ),
              ),
              Text('process, not result', style: DojiType.hint.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in reasons)
            Semantics(
              container: true,
              label: '${r.text}: ${r.kept ? 'kept' : 'broken'}',
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: r.kept ? DojiColors.dojiGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: r.kept ? DojiColors.dojiGreen : DojiColors.tiltOrange,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          r.kept ? Icons.check_rounded : Icons.close_rounded,
                          size: 14,
                          color: r.kept ? DojiColors.bg : DojiColors.tiltOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.text, style: DojiType.body.copyWith(fontSize: 14))),
                      const SizedBox(width: 8),
                      Text(
                        r.kept ? 'kept' : 'broken',
                        style: DojiType.hint.copyWith(
                          fontSize: 11,
                          color: r.kept ? DojiColors.dojiGreen : DojiColors.tiltOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.trade});

  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final notes = TradeReviewNotes.of(setup: t.setup, mistakes: t.mistakes, won: t.isWin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('TAGS', style: DojiType.label.copyWith(fontSize: 11))),
        const SizedBox(height: 10),
        if (t.mistakes.isEmpty)
          Text('no mistakes tagged.', style: DojiType.callout.copyWith(fontSize: 14))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final m in t.mistakes) MistakeTagChip(tag: m, large: true)],
          ),
        if (t.before != null || t.after != null) ...[
          const SizedBox(height: 10),
          EmotionTag(before: t.before, after: t.after),
        ],
        if (t.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: DojiColors.elevated1, borderRadius: BorderRadius.circular(12)),
            child: Text('"${t.note}"', style: DojiType.body.copyWith(fontSize: 15, height: 1.45)),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: DojiColors.dojiGreen.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('TRADE REVIEW', style: DojiType.label.copyWith(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              _Note('right', DojiColors.dojiGreen, notes.right),
              _Note(
                'broke plan',
                notes.broke.startsWith('nothing') ? DojiColors.textSecondary : DojiColors.tiltOrange,
                notes.broke,
              ),
              _Note('lesson', DojiColors.textPrimary, notes.lesson),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DojiColors.separator)),
                ),
                child: Text(
                  'from your own tags. about this trade only, not the market.',
                  style: DojiType.hint.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.kind, this.color, this.text);

  final String kind;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        style: DojiType.aiOutput.copyWith(fontSize: 14, color: DojiColors.textPrimary),
        children: [
          TextSpan(
            text: '> $kind: ',
            style: TextStyle(color: color),
          ),
          TextSpan(text: text),
        ],
      ),
    ),
  );
}

class _DeleteRow extends StatelessWidget {
  const _DeleteRow({
    required this.confirming,
    required this.onAsk,
    required this.onKeep,
    required this.onDelete,
  });

  final bool confirming;
  final VoidCallback onAsk;
  final VoidCallback onKeep;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (!confirming) {
      return Align(
        alignment: Alignment.centerLeft,
        child: DojiButton(
          label: 'delete trade',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          expand: false,
          onPressed: onAsk,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TerminalLine('this removes the trade from your journal.', tone: TerminalTone.tilt),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DojiButton(
                label: 'keep it',
                variant: DojiButtonVariant.outline,
                size: DojiButtonSize.small,
                onPressed: onKeep,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DojiButton(
                label: 'delete',
                variant: DojiButtonVariant.cautionOutline,
                size: DojiButtonSize.small,
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "how you got here": the chart notes that led to this trade (each mark,
/// the trader's reason, the co-pilot's line, the pre-trade check). Hidden
/// when there are none.
class _ChartNotes extends ConsumerWidget {
  const _ChartNotes({required this.tradeId, required this.decimals});

  final String tradeId;
  final int decimals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(chartNotesProvider).where((n) => n.tradeId == tradeId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('HOW YOU GOT HERE', style: DojiType.label)),
        const SizedBox(height: 8),
        for (final n in notes) _ChartNoteCard(note: n, decimals: decimals),
      ],
    );
  }
}

class _ChartNoteCard extends StatelessWidget {
  const _ChartNoteCard({required this.note, required this.decimals});

  final ChartNote note;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final reply = n.copilot.where((t) => !t.fromYou).lastOrNull?.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HomeCard(
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${whenLabel(n.createdAt)} · ${n.timeframe.label} · ${n.drawing.describe(decimals)}',
                style: DojiType.hint,
              ),
              if (n.drawing.stopSide != null) Text(n.drawing.stopSide!, style: DojiType.hint),
              const SizedBox(height: 6),
              Text(
                n.reason == null ? 'no reason given' : 'you: ${n.reason}',
                style: DojiType.callout.copyWith(fontSize: 14),
              ),
              if (reply != null) Text('doji: $reply', style: DojiType.callout.copyWith(fontSize: 14)),
              if (n.checklist != null && n.checklist!.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final c in n.checklist!)
                  Text(
                    '${c.label} · ${_status(c.status)}${c.answer == null ? '' : ' · you: ${c.answer!.label}'}',
                    style: DojiType.hint,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _status(String s) => switch (s) {
    'met' => 'met',
    'notMet' => 'not met',
    'waiting' => 'waiting',
    'limitHit' => 'limit reached',
    _ => 'ok',
  };
}

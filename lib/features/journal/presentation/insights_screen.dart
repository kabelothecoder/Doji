import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../analyst/presentation/weekly_review_card.dart' show showAnalystChatSheet;
import '../../home/presentation/widgets/home_card.dart' show HomeCard, HomeEyebrow;
import '../data/insights_repository.dart';
import '../domain/insights.dart';
import '../domain/trade.dart';
import 'journal_controller.dart';
import 'widgets/dashed_border.dart';
import 'widgets/journal_page.dart';
import 'widgets/journal_segmented.dart';
import 'widgets/trade_row.dart';

const String kInsightsFooter = 'from your own past trades. not a forecast, not financial advice.';

enum InsightFilter {
  all('all'),
  leaks('leaks'),
  edges('edges'),
  watching('watching');

  const InsightFilter(this.label);
  final String label;
}

/// Insight card (design: Doji Insight Card, full variant): kind, headline, one bar per trade,
/// total R and count, the small-sample note, see the trades / add as rule / watch / not useful.
/// Hidden = the dashed "hidden" row with undo.
class InsightCard extends ConsumerWidget {
  const InsightCard({super.key, required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(insightPrefsProvider);
    final c = ref.read(insightPrefsProvider.notifier);
    final i = insight;
    if (prefs.hidden.contains(i.id)) {
      return DashedBorder(
        radius: DojiRadius.card,
        color: DojiColors.separator,
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '> hidden. fewer ${i.type} insights from now on.',
                  style: DojiType.hint.copyWith(fontSize: 12),
                ),
              ),
            ),
            DojiButton(
              label: 'undo',
              variant: DojiButtonVariant.text,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: () => c.toggleHidden(i.id),
            ),
          ],
        ),
      );
    }
    final watching = prefs.watching.contains(i.id);
    final ruled = prefs.ruled.contains(i.id);
    final color = _kindColor(i.kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _KindBadge(kind: i.kind, type: i.type),
              const Spacer(),
              if (watching)
                Row(
                  children: [
                    const Icon(Icons.push_pin, size: 14, color: DojiColors.textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'watching',
                      style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textPrimary),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          DojiPressable(
            onPressed: () => context.go(Routes.insight(i.id)),
            semanticLabel: '${i.kind.name}: ${i.headline}. open',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  i.headline,
                  style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w500, height: 1.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: InsightBars(trades: i.trades, height: 40, last: 14)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rText(i.totalR), style: DojiType.data.copyWith(fontSize: 18, color: color)),
                  Text(
                    '${i.n} trades',
                    style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          if (i.note case final note?) ...[
            const SizedBox(height: 12),
            DashedBorder(
              radius: 8,
              color: const Color(0xFF3A3D42),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('> $note', style: DojiType.hint.copyWith(fontSize: 12)),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: DojiColors.elevated2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DojiButton(
                label: 'see the trades',
                variant: DojiButtonVariant.text,
                size: DojiButtonSize.small,
                expand: false,
                onPressed: () => context.go(Routes.insight(i.id, trades: true)),
              ),
              _RuleButton(ruled: ruled, onPressed: () => unawaited(c.addRule(i))),
              DojiIconButton(
                icon: watching ? Icons.push_pin : Icons.push_pin_outlined,
                semanticLabel: watching ? 'stop watching' : 'watch this',
                outlined: false,
                background: Colors.transparent,
                foreground: watching ? DojiColors.textPrimary : DojiColors.textSecondary,
                iconSize: 20,
                onPressed: () => c.toggleWatch(i.id),
              ),
              DojiIconButton(
                icon: Icons.thumb_down_outlined,
                semanticLabel: 'not useful',
                outlined: false,
                background: Colors.transparent,
                foreground: DojiColors.textSecondary,
                iconSize: 20,
                onPressed: () => c.toggleHidden(i.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _kindColor(InsightKind k) => k == InsightKind.edge ? DojiColors.dojiGreen : DojiColors.tiltOrange;

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.type});

  final InsightKind kind;
  final String type;

  @override
  Widget build(BuildContext context) {
    final edge = kind == InsightKind.edge;
    final color = _kindColor(kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: edge ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(edge ? Icons.add : Icons.remove, size: 14, color: edge ? DojiColors.bg : color),
        ),
        const SizedBox(width: 8),
        Text(edge ? 'EDGE' : 'LEAK', style: DojiType.label.copyWith(fontSize: 11, color: color)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '· $type',
            style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _RuleButton extends StatelessWidget {
  const _RuleButton({required this.ruled, required this.onPressed});

  final bool ruled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: ruled,
    child: DojiButton(
      label: ruled ? 'rule added' : 'add as rule',
      icon: Icon(ruled ? Icons.check : Icons.add, size: 18),
      variant: ruled ? DojiButtonVariant.ghost : DojiButtonVariant.neutral,
      size: DojiButtonSize.small,
      expand: false,
      onPressed: ruled ? null : onPressed,
    ),
  );
}

/// One bar per trade (the newest [last]): wins filled above the line, losses hollow below.
/// Colour is never the only signal: the semantics label says how many of each.
class InsightBars extends StatelessWidget {
  const InsightBars({super.key, required this.trades, this.height = 120, this.last = 30});

  final List<Trade> trades;
  final double height;
  final int last;

  @override
  Widget build(BuildContext context) {
    final shown = trades.length > last ? trades.sublist(trades.length - last) : trades;
    final maxR = shown.fold(1.0, (m, t) => math.max(m, t.r!.abs()));
    final above = shown.where((t) => t.r! > 0).length;
    return Semantics(
      label: '${shown.length} trades. $above above the line, ${shown.length - above} at or below it.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: CustomPaint(painter: _BarsPainter([for (final t in shown) t.r! / maxR])),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = DojiColors.separator);
    if (values.isEmpty) return;
    const gap = 3.0;
    final w = (size.width - gap * (values.length - 1)) / values.length;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = math.max(3.0, v.abs() * mid);
      final x = i * (w + gap);
      final r = RRect.fromRectAndRadius(
        v > 0 ? Rect.fromLTWH(x, mid - h, w, h) : Rect.fromLTWH(x + .75, mid, w - 1.5, h - .75),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        r,
        v > 0
            ? (Paint()..color = DojiColors.dojiGreen)
            : (Paint()
                ..color = DojiColors.tiltOrange
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values;
}

/// The two newest insights for the journal home, with "all insights".
class InsightsPreview extends ConsumerWidget {
  const InsightsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(insightPrefsProvider.select((p) => p.hidden));
    final list = ref.watch(insightsProvider).where((i) => !hidden.contains(i.id)).take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: HomeEyebrow('INSIGHTS')),
            Transform.translate(
              offset: const Offset(8, 0),
              child: DojiButton(
                label: 'all insights',
                variant: DojiButtonVariant.ghost,
                size: DojiButtonSize.small,
                expand: false,
                onPressed: () => context.go(Routes.insights),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Text('> no pattern stands out in your trades yet.', style: DojiType.hint.copyWith(fontSize: 13))
        else
          for (final i in list) ...[InsightCard(insight: i), const SizedBox(height: 10)],
      ],
    );
  }
}

/// Insights feed (design: Doji Trade Journal Phone › insights).
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightFilter _filter = InsightFilter.all;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(insightsProvider);
    final prefs = ref.watch(insightPrefsProvider);
    final count = ref.watch(activeAccountTradesProvider).length;
    final shown = [
      for (final i in all)
        if (switch (_filter) {
          InsightFilter.all => true,
          InsightFilter.leaks => i.kind == InsightKind.leak,
          InsightFilter.edges => i.kind == InsightKind.edge,
          InsightFilter.watching => prefs.watching.contains(i.id),
        })
          i,
    ];
    return JournalPage(
      children: [
        JournalBackBar(
          label: 'journal',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.journal),
        ),
        Semantics(header: true, child: Text('insights', style: DojiType.title)),
        TerminalLine('from your $count trades on this account', liveRegion: false),
        JournalSegmented<InsightFilter>(
          values: InsightFilter.values,
          selected: _filter,
          groupLabel: 'filter insights',
          labelOf: (f) => f.label,
          semanticOf: (f) => 'show ${f.label}',
          onChanged: (f) => setState(() => _filter = f),
        ),
        DojiButton(
          label: 'ask your journal',
          icon: const Icon(Icons.forum_outlined, size: 18),
          variant: DojiButtonVariant.outline,
          onPressed: () => unawaited(showAnalystChatSheet(context)),
        ),
        if (all.isEmpty)
          Text(
            count < 20
                ? '> insights unlock at 20 trades. this account has $count.'
                : '> no pattern stands out yet. each one needs at least $kInsightMinTrades trades with a stop.',
            style: DojiType.hint.copyWith(fontSize: 14),
          )
        else if (shown.isEmpty)
          Text(
            _filter == InsightFilter.watching
                ? '> nothing pinned yet. tap the pin on any insight to watch it.'
                : '> none of these in your trades.',
            style: DojiType.hint.copyWith(fontSize: 14),
          )
        else
          for (final i in shown) InsightCard(insight: i),
        Text(kInsightsFooter, style: DojiType.hint.copyWith(fontSize: 11, height: 1.5)),
      ],
    );
  }
}

/// One insight (design: Doji Trade Journal Phone › insight): evidence, each trade's bar, how doji
/// found it, the sample, watch / not useful, and the trades themselves.
class InsightDetailScreen extends ConsumerStatefulWidget {
  const InsightDetailScreen({super.key, required this.id, this.toTrades = false});

  final String id;

  /// Opened from "see the trades": scroll to them.
  final bool toTrades;

  @override
  ConsumerState<InsightDetailScreen> createState() => _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  final _tradesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.toTrades) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _tradesKey.currentContext;
        if (ctx != null && mounted) unawaited(Scrollable.ensureVisible(ctx));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(insightsProvider).where((x) => x.id == widget.id).firstOrNull;
    void back() => context.canPop() ? context.pop() : context.go(Routes.insights);
    if (i == null) {
      return JournalPage(
        children: [
          JournalBackBar(label: 'insights', onBack: back),
          Text('> this insight no longer shows in your trades.', style: DojiType.hint.copyWith(fontSize: 14)),
        ],
      );
    }
    final prefs = ref.watch(insightPrefsProvider);
    final c = ref.read(insightPrefsProvider.notifier);
    final watching = prefs.watching.contains(i.id);
    final ruled = prefs.ruled.contains(i.id);
    final color = _kindColor(i.kind);
    final view = ref.watch(journalViewProvider);
    final symbol = ref.watch(accountCurrencyProvider).symbol;
    Widget stat(String v, String l, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DojiColors.separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v, style: DojiType.data.copyWith(fontSize: 18, color: c)),
            Text(l, style: DojiType.label.copyWith(fontSize: 10, color: DojiColors.textSecondary)),
          ],
        ),
      ),
    );
    return JournalPage(
      children: [
        JournalBackBar(label: 'insights', onBack: back),
        _KindBadge(kind: i.kind, type: i.type),
        Semantics(
          header: true,
          child: Text(i.headline, style: DojiType.title.copyWith(fontSize: 26, height: 1.2)),
        ),
        Row(
          children: [
            stat('${i.n}', 'trades', DojiColors.textPrimary),
            const SizedBox(width: 8),
            stat(rText(i.totalR), 'total', color),
            const SizedBox(width: 8),
            stat(rText(i.perTradeR), 'per trade', color),
          ],
        ),
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeEyebrow('EACH TRADE IN THIS PATTERN'),
              const SizedBox(height: 10),
              InsightBars(trades: i.trades),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'oldest',
                    style: DojiType.label.copyWith(fontSize: 10, color: DojiColors.textTertiary),
                  ),
                  const Spacer(),
                  Text(
                    'latest',
                    style: DojiType.label.copyWith(fontSize: 10, color: DojiColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const HomeEyebrow('HOW DOJI FOUND THIS'),
        for (final line in i.how) TerminalLine(line, liveRegion: false),
        DashedBorder(
          radius: 12,
          color: i.smallSample ? DojiColors.textSecondary : DojiColors.separator,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                children: [
                  Text(
                    'sample: ${i.n} trades',
                    style: DojiType.label.copyWith(color: DojiColors.textPrimary),
                  ),
                  Text(i.smallSample ? 'small sample' : 'larger sample', style: DojiType.label),
                ],
              ),
              if (i.note case final note?) ...[
                const SizedBox(height: 6),
                Text('> $note', style: DojiType.hint.copyWith(fontSize: 12)),
              ],
            ],
          ),
        ),
        Semantics(
          toggled: watching,
          child: DojiButton(
            label: watching ? 'watching' : 'watch this',
            icon: Icon(watching ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
            variant: DojiButtonVariant.outline,
            size: DojiButtonSize.regular,
            onPressed: () => c.toggleWatch(i.id),
          ),
        ),
        DojiButton(
          label: 'not useful',
          icon: const Icon(Icons.thumb_down_outlined, size: 18),
          variant: DojiButtonVariant.outline,
          size: DojiButtonSize.regular,
          onPressed: () {
            if (!prefs.hidden.contains(i.id)) c.toggleHidden(i.id);
            back();
          },
        ),
        DojiButton(
          label: ruled ? 'rule added · ${i.rule}' : 'add as rule · ${i.rule}',
          variant: ruled ? DojiButtonVariant.outline : DojiButtonVariant.primary,
          onPressed: ruled ? null : () => unawaited(c.addRule(i)),
        ),
        Text(
          'added to "when i don\'t trade" on this account\'s strategy. edit it in settings › accounts.',
          style: DojiType.hint.copyWith(fontSize: 12),
        ),
        Column(
          key: _tradesKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeEyebrow('THE TRADES'),
            for (final t in i.trades.reversed)
              TradeRow(
                trade: t,
                unit: view.unit,
                currencySymbol: symbol,
                onTap: () => unawaited(context.push(Routes.tradeDetail(t.id))),
              ),
          ],
        ),
        Text(kInsightsFooter, style: DojiType.hint.copyWith(fontSize: 11, height: 1.5)),
      ],
    );
  }
}

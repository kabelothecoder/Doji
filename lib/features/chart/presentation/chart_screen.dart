import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/layout.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../coach/domain/coach.dart';
import '../../journal/domain/formatting.dart' show formatMoney;
import '../../journal/presentation/journal_controller.dart';
import '../../markets/data/live_rate_source.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/market_data.dart';
import '../../markets/domain/market_format.dart';
import '../../markets/domain/time_zones.dart';
import '../../markets/domain/currency.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../markets/presentation/widgets/timeframe_tabs.dart';
import '../../onboarding/domain/user_zone.dart';
import '../domain/chart_viewport.dart';
import '../domain/drawing.dart';
import '../domain/position_math.dart';
import 'chart_controller.dart';
import 'pre_trade_check_sheet.dart';
import 'what_is_this_sheet.dart';
import 'widgets/chart_sheet.dart';
import 'widgets/doji_chart.dart';
import 'widgets/drawing_list.dart';

/// doji's chart for one instrument (`/markets/chart/:symbol`): pan, zoom,
/// timeframes, crosshair, the drawing tools, the accessible drawings list,
/// and the co-pilot after each mark. No design file (design/SOURCE.md ›
/// Missing): built from `core/widgets/`.
///
/// Keys (Windows): V select, R zone, H level, T trend line, P position,
/// ← → pan (or move the selected drawing a bar), ↑ ↓ move it a tick, + −
/// zoom, Delete, Ctrl+Z / Ctrl+Y, Esc.
class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  final _focus = FocusNode(debugLabel: 'chart');

  String get _symbol => widget.symbol.toUpperCase();
  ChartController get _c => ref.read(chartControllerProvider(_symbol).notifier);

  @override
  void initState() {
    super.initState();
    // Fetch the quote-to-account rate once, so position boxes can size.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quote = instrumentBySymbol(_symbol)?.quoteCurrency;
      if (!mounted || quote == null) return;
      final currency = ref.read(marketsProfileProvider).accountCurrency;
      await ref.read(rateSourceProvider).prepare(quote, currency);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.pairDetail(_symbol));

  List<Candle> get _bars =>
      ref.read(chartBarsProvider((_symbol, ref.read(chartControllerProvider(_symbol)).timeframe))).value ??
      const [];

  ChartViewport _viewport(ChartState s, int total) => s.viewport ?? ChartViewport.latest(total);

  Future<void> _created(Drawing d) async {
    await _c.create(d);
    if (!mounted) return;
    if (d.kind == DrawingKind.position) {
      final profile = ref.read(marketsProfileProvider);
      final rows = await showPreTradeCheck(
        context,
        conditions: ref.read(pairBriefProvider(_symbol)).value?.conditions ?? const [],
        coach: CoachContext.from(profile, trades: ref.read(activeAccountTradesProvider), now: clock.now()),
      );
      if (rows != null) await _c.saveChecklist(d.id, rows);
      if (!mounted || GoRouter.of(context).state.matchedLocation != Routes.chart(_symbol)) return;
    }
    await _askReason(d.id);
  }

  Future<void> _askReason(String id) async {
    final d = ref.read(chartControllerProvider(_symbol)).editor.byId(id);
    if (d == null) return;
    await showWhatIsThis(
      context,
      symbol: _symbol,
      noteId: id,
      drawingName: d.describe(_decimals),
      bars: _bars,
    );
    if (mounted) _focus.requestFocus();
  }

  int get _decimals => ref.read(pairQuoteProvider(_symbol)).value?.decimals ?? _fallbackDecimals;

  int get _fallbackDecimals {
    final tick = instrumentBySymbol(_symbol)?.tickSize;
    if (tick == null) return 2;
    final s = tick.toString();
    return s.contains('.') ? s.split('.').last.length : 0;
  }

  bool _typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null &&
        (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_typing()) return KeyEventResult.ignored;
    final s = ref.read(chartControllerProvider(_symbol));
    final bars = _bars;
    final k = e.logicalKey;
    final kb = HardwareKeyboard.instance;
    final ctrl = kb.isControlPressed || kb.isMetaPressed;
    final v = _viewport(s, bars.length);
    if (ctrl && k == LogicalKeyboardKey.keyZ) {
      unawaited(kb.isShiftPressed ? _c.redo() : _c.undo());
    } else if (ctrl && k == LogicalKeyboardKey.keyY) {
      unawaited(_c.redo());
    } else if (ctrl) {
      return KeyEventResult.ignored;
    } else if (k == LogicalKeyboardKey.escape) {
      if (s.selectedId != null) {
        _c.select(null);
      } else if (s.tool != ChartTool.select) {
        _c.setTool(ChartTool.select);
      } else {
        _back();
      }
    } else if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      unawaited(_c.deleteSelected());
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      final dir = k == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      if (s.selectedId != null) {
        unawaited(_c.nudge(bars: dir, priceStep: _c.priceStep(bars)));
      } else {
        _c.setViewport(v.pan(dir * 5.0, bars.length));
      }
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      if (s.selectedId == null) return KeyEventResult.ignored;
      unawaited(_c.nudge(steps: k == LogicalKeyboardKey.arrowUp ? 1 : -1, priceStep: _c.priceStep(bars)));
    } else if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _c.setViewport(v.zoom(1.25, 1, bars.length));
    } else if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _c.setViewport(v.zoom(1 / 1.25, 1, bars.length));
    } else if (k == LogicalKeyboardKey.enter && s.selectedId != null) {
      unawaited(_askReason(s.selectedId!));
    } else {
      final tool = ChartTool.forKey(k);
      if (tool == null) return KeyEventResult.ignored;
      _c.setTool(tool);
    }
    return KeyEventResult.handled;
  }

  String _positionLabel(Drawing d) {
    final profile = ref.read(marketsProfileProvider);
    final currency = AccountCurrency.fromCode(profile.accountCurrency) ?? AccountCurrency.fallback;
    final f = PositionFigures.of(
      d,
      instrument: instrumentBySymbol(_symbol),
      startingSize: profile.startingSize,
      riskPct: profile.rules?.riskPerTrade,
      currency: currency.code,
      rates: ref.read(rateSourceProvider),
    );
    return [
      'plan',
      if (f.r != null) '1 : ${f.r!.toStringAsFixed(1)} R',
      if (f.riskMoney != null)
        'risk ${formatMoney(f.riskMoney!, currency.symbol, signed: false)} (${_n(f.riskPct!)}%)',
      f.size == null ? 'size: broker figure needed' : '${f.size!.toStringAsFixed(2)} lots',
    ].join(' · ');
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _timeLabel(DateTime t, Timeframe tf, UserZone zone) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final d = onClock(zone, t);
    final day = '${months[d.month - 1]} ${d.day}';
    return tf == Timeframe.d1 ? day : '$day ${clockTime(zone, t)}';
  }

  Future<void> _openList(ChartState s, List<Candle> bars) => showChartSheet<void>(
    context,
    label: 'drawings',
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final live = ref.watch(chartControllerProvider(_symbol));
        return _list(live, bars, inSheet: sheet);
      },
    ),
  );

  Widget _list(ChartState s, List<Candle> bars, {BuildContext? inSheet}) => DrawingList(
    drawings: s.drawings,
    selectedId: s.selectedId,
    decimals: _decimals,
    bars: bars,
    timeframe: s.timeframe,
    onSelect: (id) {
      _c.select(id);
      if (inSheet != null) Navigator.of(inSheet).pop();
    },
    onReason: (id) {
      if (inSheet != null) Navigator.of(inSheet).pop();
      unawaited(_askReason(id));
    },
    onDelete: (id) => unawaited(_c.delete(id)),
    onAdd: (d) {
      if (inSheet != null) Navigator.of(inSheet).pop();
      unawaited(_created(d));
    },
  );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(chartControllerProvider(_symbol));
    final bars = ref.watch(chartBarsProvider((_symbol, s.timeframe)));
    // Kept alive for the pre-trade check and the co-pilot's conditions.
    ref.watch(pairBriefProvider(_symbol));
    ref.watch(pairQuoteProvider(_symbol));
    final source = ref.watch(barSourceProvider(_symbol)).source;
    final zone = userZoneFromProfile(ref.watch(marketsProfileProvider));
    final name = instrumentLabel(_symbol);
    final wide = isWideLayout(context) && MediaQuery.sizeOf(context).width >= 760;
    final list = bars.value ?? const <Candle>[];

    final chart = switch (bars) {
      AsyncError(:final error) => _Message(
        text: error is FeedUnavailable ? 'price feed not responding.' : 'no chart for $name right now.',
        onRetry: () => ref.invalidate(chartBarsProvider((_symbol, s.timeframe))),
      ),
      AsyncData(:final value) when value.isEmpty => _Message(text: 'no chart for $name yet.'),
      AsyncData(:final value) => DojiChart(
        bars: value,
        timeframe: s.timeframe,
        decimals: _decimals,
        viewport: _viewport(s, value.length),
        drawings: s.drawings,
        selectedId: s.selectedId,
        tool: s.tool.kind,
        semanticLabel:
            'Candlestick chart for $name, ${s.timeframe.spoken}, ${source.live ? 'live prices' : 'sample prices'}, '
            '${s.drawings.length} drawings. The drawings list has each one.',
        positionLabel: _positionLabel,
        timeLabel: (t) => _timeLabel(t, s.timeframe, zone),
        onViewport: _c.setViewport,
        onCreate: (d) => unawaited(_created(d)),
        onChange: (d) => unawaited(_c.change(d)),
        onSelect: _c.select,
      ),
      _ => Center(child: TerminalLine('loading $name', cursor: true, liveRegion: false)),
    };

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: DojiColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DojiIconButton(icon: Icons.arrow_back_rounded, semanticLabel: 'back', onPressed: _back),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(name, style: DojiType.headline.copyWith(fontFamily: DojiFonts.mono)),
                          ),
                          Text(source.label, style: DojiType.hint, maxLines: 2),
                        ],
                      ),
                    ),
                    if (!wide)
                      DojiButton(
                        label: 'drawings (${s.drawings.length})',
                        variant: DojiButtonVariant.outline,
                        size: DojiButtonSize.small,
                        expand: false,
                        onPressed: () => unawaited(_openList(s, list)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TimeframeTabs(selected: s.timeframe, onChanged: _c.setTimeframe),
                const SizedBox(height: 8),
                _Toolbar(state: s, controller: _c),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: DojiColors.elevated1,
                            borderRadius: BorderRadius.circular(DojiRadius.card),
                          ),
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(8),
                          child: chart,
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 12),
                        SizedBox(width: 340, child: SingleChildScrollView(child: _list(s, list))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tools, then undo / redo / delete. Every one has a label and a key.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.controller});

  final ChartState state;
  final ChartController controller;

  static IconData _icon(ChartTool t) => switch (t) {
    ChartTool.select => Icons.near_me_outlined,
    ChartTool.zone => Icons.crop_square_rounded,
    ChartTool.level => Icons.horizontal_rule_rounded,
    ChartTool.trendLine => Icons.timeline_rounded,
    ChartTool.position => Icons.straighten_rounded,
  };

  Widget _button(IconData icon, String label, String key, VoidCallback? onPressed, {bool selected = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: '$label ($key)',
          child: DojiIconButton(
            icon: icon,
            semanticLabel: '$label${selected ? ', selected' : ''}',
            filled: selected,
            onPressed: onPressed,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = state;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in ChartTool.values)
            _button(_icon(t), t.label, t.key, () => controller.setTool(t), selected: s.tool == t),
          const SizedBox(width: 10),
          _button(
            Icons.undo_rounded,
            'undo',
            'Ctrl+Z',
            s.editor.canUndo ? () => unawaited(controller.undo()) : null,
          ),
          _button(
            Icons.redo_rounded,
            'redo',
            'Ctrl+Y',
            s.editor.canRedo ? () => unawaited(controller.redo()) : null,
          ),
          _button(
            Icons.delete_outline_rounded,
            'delete drawing',
            'Delete',
            s.selectedId == null ? null : () => unawaited(controller.deleteSelected()),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: DojiType.callout, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          DojiButton(
            label: 'try again',
            variant: DojiButtonVariant.outline,
            size: DojiButtonSize.small,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ],
    ),
  );
}

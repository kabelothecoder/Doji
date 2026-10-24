import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../markets/data/placeholder_rate_source.dart';
import '../../markets/domain/instrument.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/formatting.dart';
import '../domain/trade.dart';
import '../domain/trade_math.dart';
import 'journal_controller.dart';
import 'widgets/journal_page.dart';

/// Add one trade by hand (Doji Trade Journal › manual): the instrument,
/// direction, prices, size and times. The result and the risk are worked out
/// from the instrument; where they cannot be (a Deriv synthetic, a symbol
/// doji does not know), the trader types the broker's figure. Saving goes
/// straight to the review sheet.
class ManualTradeScreen extends ConsumerStatefulWidget {
  const ManualTradeScreen({super.key});

  @override
  ConsumerState<ManualTradeScreen> createState() => _ManualTradeScreenState();
}

class _ManualTradeScreenState extends ConsumerState<ManualTradeScreen> {
  final _entry = TextEditingController();
  final _exit = TextEditingController();
  final _stop = TextEditingController();
  final _target = TextEditingController();
  final _size = TextEditingController();
  final _result = TextEditingController();
  final _risk = TextEditingController();
  final _other = TextEditingController();

  String? _symbol;
  bool _otherSymbol = false;
  TradeDirection _direction = TradeDirection.long;
  late DateTime _closed = clock.now();
  late DateTime _opened = _closed.subtract(const Duration(minutes: 30));

  late final List<TextEditingController> _all = [
    _entry,
    _exit,
    _stop,
    _target,
    _size,
    _result,
    _risk,
    _other,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  List<String> _symbolChoices() {
    final mine = ref.read(journalProfileProvider).instruments;
    return mine.isEmpty ? defaultInstruments : mine;
  }

  String? get _activeSymbol {
    if (_otherSymbol) {
      final s = _other.text.trim().toUpperCase();
      return s.isEmpty ? null : s;
    }
    return _symbol ?? _symbolChoices().first;
  }

  Future<void> _pick(bool opening) async {
    final current = opening ? _opened : _closed;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: clock.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null || !mounted) return;
    final value = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    setState(() => opening ? _opened = value : _closed = value);
  }

  /// Everything the form works out, or the reason it cannot save yet.
  _Draft _draft() {
    final symbol = _activeSymbol;
    final instrument = symbol == null ? null : instrumentBySymbol(symbol);
    final entry = _num(_entry),
        exit = _num(_exit),
        stop = _num(_stop),
        target = _num(_target),
        size = _num(_size);
    final currency = ref.read(journalProfileProvider).accountCurrency;
    const rates = PlaceholderRateSource();

    double? pnl;
    double? risk;
    var computed = false;
    if (entry != null && exit != null && size != null && size > 0) {
      pnl = TradeMath.pnl(
        instrument: instrument,
        direction: _direction,
        entry: entry,
        exit: exit,
        size: size,
        accountCurrency: currency,
        rates: rates,
      );
      computed = pnl != null;
      risk = TradeMath.riskMoney(
        instrument: instrument,
        entry: entry,
        stop: stop,
        size: size,
        accountCurrency: currency,
        rates: rates,
      );
    }
    final needsFigure = entry != null && exit != null && size != null && size > 0 && !computed;
    if (needsFigure) {
      pnl = _num(_result);
      final r = _num(_risk);
      risk = r != null && r > 0 ? r : null;
    }

    String? error;
    if (stop != null && entry != null) {
      if (_direction == TradeDirection.long && stop >= entry) {
        error = 'for a long, the stop sits below the entry.';
      } else if (_direction == TradeDirection.short && stop <= entry) {
        error = 'for a short, the stop sits above the entry.';
      }
    }
    if (error == null && target != null && entry != null) {
      if (_direction == TradeDirection.long && target <= entry) {
        error = 'for a long, the target sits above the entry.';
      } else if (_direction == TradeDirection.short && target >= entry) {
        error = 'for a short, the target sits below the entry.';
      }
    }
    if (error == null && _closed.isBefore(_opened)) error = 'it closed before it opened.';

    final ready =
        symbol != null &&
        entry != null &&
        exit != null &&
        size != null &&
        size > 0 &&
        pnl != null &&
        error == null;
    return _Draft(
      symbol: symbol,
      instrument: instrument,
      entry: entry,
      exit: exit,
      stop: stop,
      target: target,
      size: size,
      pnl: pnl,
      risk: risk,
      computed: computed,
      needsFigure: needsFigure,
      usesRate: computed && TradeMath.usesRate(instrument, currency),
      error: error,
      ready: ready,
    );
  }

  Future<void> _save(_Draft d) async {
    if (!d.ready) return;
    final trade = Trade(
      id: JournalController.newId(),
      symbol: d.symbol!,
      direction: _direction,
      openedAt: _opened.toUtc(),
      closedAt: _closed.toUtc(),
      entry: d.entry!,
      exit: d.exit!,
      stop: d.stop,
      target: d.target,
      size: d.size!,
      pnl: d.pnl!,
      riskMoney: d.risk,
    );
    unawaited(ref.read(hapticsProvider).light());
    await ref.read(journalControllerProvider.notifier).add(trade);
    if (!mounted) return;
    context.pushReplacement(Routes.tradeDetail(trade.id, review: true));
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(accountCurrencyProvider);
    final d = _draft();
    final choices = _symbolChoices();
    final active = _activeSymbol;

    const price = TextInputType.numberWithOptions(decimal: true);
    final priceFormat = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    Widget field(
      String label,
      TextEditingController c, {
      String hint = '',
      TextInputType? type,
      bool signed = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: DojiType.label.copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        DojiTextField(
          controller: c,
          large: false,
          hint: hint,
          semanticLabel: label,
          keyboardType: type ?? price,
          inputFormatters: signed ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))] : priceFormat,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ],
    );

    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );

    Widget timeTile(String label, DateTime value, bool opening) => DojiPressable(
      onPressed: () => unawaited(_pick(opening)),
      borderRadius: BorderRadius.circular(DojiRadius.card),
      semanticLabel: '$label ${whenLabel(value)}, change',
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: BorderRadius.circular(DojiRadius.card),
          border: Border.all(color: DojiColors.separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: DojiType.label.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            Text(whenLabel(value), style: DojiType.data.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );

    String preview() {
      final pnl = d.pnl!;
      final r = d.risk == null || d.risk! <= 0 ? null : pnl / d.risk!;
      return '${formatMoney(pnl, currency.symbol)}${r == null ? ' · no stop, so no R' : ' · ${formatR(r)}'}';
    }

    return JournalPage(
      children: [
        JournalBackBar(
          label: 'back',
          onBack: () => context.canPop() ? context.pop() : context.go(Routes.journal),
        ),
        Semantics(header: true, child: Text('add a trade', style: DojiType.title)),
        Text('about a minute. you review it right after.', style: DojiType.callout.copyWith(fontSize: 14)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INSTRUMENT', style: DojiType.label.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in choices)
                  DojiChoiceChip(
                    label: instrumentLabel(s),
                    mono: true,
                    selected: !_otherSymbol && (active == s),
                    exclusive: true,
                    style: DojiChoiceStyle.chip,
                    onTap: () => setState(() {
                      _otherSymbol = false;
                      _symbol = s;
                    }),
                  ),
                DojiChoiceChip(
                  label: '+ other',
                  selected: _otherSymbol,
                  dashed: !_otherSymbol,
                  exclusive: true,
                  style: DojiChoiceStyle.chip,
                  onTap: () => setState(() => _otherSymbol = true),
                ),
              ],
            ),
            if (_otherSymbol) ...[
              const SizedBox(height: 10),
              DojiTextField(
                controller: _other,
                large: false,
                hint: 'symbol, e.g. EURUSD',
                semanticLabel: 'symbol',
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DIRECTION', style: DojiType.label.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final dir in TradeDirection.values) ...[
                  if (dir != TradeDirection.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: DojiChoiceChip(
                      label: dir.label,
                      selected: _direction == dir,
                      exclusive: true,
                      center: true,
                      style: DojiChoiceStyle.chip,
                      onTap: () => setState(() => _direction = dir),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        pair(field('entry', _entry, hint: '0.0'), field('exit', _exit, hint: '0.0')),
        pair(field('stop', _stop, hint: 'for R'), field('target', _target, hint: 'optional')),
        pair(field('size · lots', _size, hint: '0.10'), const SizedBox.shrink()),
        if (d.needsFigure)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerminalLine(
                "doji can't size ${d.symbol == null ? 'this instrument' : instrumentLabel(d.symbol!)} yet. "
                "type your broker's figures.",
                liveRegion: false,
              ),
              const SizedBox(height: 10),
              pair(
                field('result · ${currency.code}', _result, hint: '-45.50', signed: true),
                field('risk · ${currency.code}', _risk, hint: 'for R'),
              ),
            ],
          ),
        pair(timeTile('opened', _opened, true), timeTile('closed', _closed, false)),
        if (d.error != null)
          TerminalLine(d.error!, tone: TerminalTone.tilt)
        else if (d.pnl != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerminalLine('result ${preview()}', tone: TerminalTone.primary, liveRegion: false),
              if (d.usesRate) ...[
                const SizedBox(height: 4),
                Text(
                  'worked out from entry, exit and size. it uses a placeholder exchange rate for ${d.instrument!.quoteCurrency}.',
                  style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
                ),
              ],
            ],
          ),
        DojiButton(label: 'save trade', onPressed: d.ready ? () => unawaited(_save(d)) : null),
      ],
    );
  }
}

class _Draft {
  const _Draft({
    required this.symbol,
    required this.instrument,
    required this.entry,
    required this.exit,
    required this.stop,
    required this.target,
    required this.size,
    required this.pnl,
    required this.risk,
    required this.computed,
    required this.needsFigure,
    required this.usesRate,
    required this.error,
    required this.ready,
  });

  final String? symbol;
  final Instrument? instrument;
  final double? entry;
  final double? exit;
  final double? stop;
  final double? target;
  final double? size;
  final double? pnl;
  final double? risk;
  final bool computed;
  final bool needsFigure;
  final bool usesRate;
  final String? error;
  final bool ready;
}

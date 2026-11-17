import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../markets/domain/candle.dart';
import '../../data/chart_note_repository.dart';
import '../../domain/drawing.dart';
import '../../domain/drawing_drafts.dart';

/// Every drawing on the chart as a list: name, price levels, the trader's
/// reason and the co-pilot's reply, with select / reason / delete. Screen
/// readers and the keyboard can also add a drawing by typing its prices, so
/// the chart is never the only way in.
class DrawingList extends ConsumerWidget {
  const DrawingList({
    super.key,
    required this.drawings,
    required this.selectedId,
    required this.decimals,
    required this.bars,
    required this.timeframe,
    required this.onSelect,
    required this.onReason,
    required this.onDelete,
    required this.onAdd,
  });

  final List<Drawing> drawings;
  final String? selectedId;
  final int decimals;
  final List<Candle> bars;
  final Timeframe timeframe;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onReason;
  final ValueChanged<String> onDelete;
  final ValueChanged<Drawing> onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = {for (final n in ref.watch(chartNotesProvider)) n.id: n};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('DRAWINGS (${drawings.length})', style: DojiType.label)),
        const SizedBox(height: 8),
        if (drawings.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('nothing drawn yet. pick a tool, or add one by price below.', style: DojiType.hint),
          ),
        for (final d in drawings)
          _Row(
            drawing: d,
            decimals: decimals,
            selected: d.id == selectedId,
            reason: notes[d.id]?.reason,
            reply: notes[d.id]?.copilot.where((t) => !t.fromYou).lastOrNull?.text,
            onSelect: () => onSelect(d.id),
            onReason: () => onReason(d.id),
            onDelete: () => onDelete(d.id),
          ),
        const SizedBox(height: 12),
        _AddByPrice(decimals: decimals, bars: bars, timeframe: timeframe, onAdd: onAdd),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.drawing,
    required this.decimals,
    required this.selected,
    required this.reason,
    required this.reply,
    required this.onSelect,
    required this.onReason,
    required this.onDelete,
  });

  final Drawing drawing;
  final int decimals;
  final bool selected;
  final String? reason;
  final String? reply;
  final VoidCallback onSelect;
  final VoidCallback onReason;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = drawing;
    final prices = d.prices.map((p) => '${p.$1} ${p.$2.toStringAsFixed(decimals)}').join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: selected ? DojiColors.textPrimary : DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${d.kind.label}${selected ? ' · selected' : ''}',
                  style: DojiType.body.copyWith(fontSize: 15),
                ),
                Text(prices, style: DojiType.hint),
                if (d.stopSide != null) Text(d.stopSide!, style: DojiType.hint),
                const SizedBox(height: 4),
                Text(
                  reason == null ? 'no reason given' : 'you: $reason',
                  style: DojiType.callout.copyWith(fontSize: 14),
                ),
                if (reply != null) Text('doji: $reply', style: DojiType.callout.copyWith(fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: [
              DojiButton(
                label: 'select',
                variant: DojiButtonVariant.text,
                size: DojiButtonSize.small,
                expand: false,
                semanticLabel: 'select ${d.kind.label}',
                onPressed: onSelect,
              ),
              DojiButton(
                label: reason == null ? 'add reason' : 'change reason',
                variant: DojiButtonVariant.text,
                size: DojiButtonSize.small,
                expand: false,
                onPressed: onReason,
              ),
              DojiButton(
                label: 'delete',
                variant: DojiButtonVariant.text,
                size: DojiButtonSize.small,
                expand: false,
                semanticLabel: 'delete ${d.kind.label}',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add a drawing by its prices (the keyboard and screen-reader path).
class _AddByPrice extends StatefulWidget {
  const _AddByPrice({
    required this.decimals,
    required this.bars,
    required this.timeframe,
    required this.onAdd,
  });

  final int decimals;
  final List<Candle> bars;
  final Timeframe timeframe;
  final ValueChanged<Drawing> onAdd;

  @override
  State<_AddByPrice> createState() => _AddByPriceState();
}

class _AddByPriceState extends State<_AddByPrice> {
  DrawingKind _kind = DrawingKind.level;
  final _fields = [TextEditingController(), TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _names => switch (_kind) {
    DrawingKind.level => ['price'],
    DrawingKind.zone => ['top', 'bottom'],
    DrawingKind.trendLine => ['from', 'to'],
    DrawingKind.position => ['entry', 'stop', 'target'],
  };

  List<double>? get _values {
    final out = <double>[];
    for (var i = 0; i < _names.length; i++) {
      final v = double.tryParse(_fields[i].text.trim().replaceAll(',', '.'));
      if (v == null || v <= 0) return null;
      out.add(v);
    }
    return out;
  }

  void _add() {
    final v = _values;
    if (v == null || widget.bars.isEmpty) return;
    final step = widget.timeframe.duration;
    final last = widget.bars.last.at;
    final from = last.subtract(step * 10);
    final d = switch (_kind) {
      DrawingKind.level => Drawing(id: newDrawingId(), kind: _kind, a: ChartPoint(last, v[0])),
      DrawingKind.zone || DrawingKind.trendLine => Drawing(
        id: newDrawingId(),
        kind: _kind,
        a: ChartPoint(from, v[0]),
        b: ChartPoint(last, v[1]),
      ),
      DrawingKind.position => Drawing(
        id: newDrawingId(),
        kind: _kind,
        a: ChartPoint(last, v[0]),
        b: ChartPoint(last.add(step * 12), v[0]),
        stop: v[1],
        target: v[2],
      ),
    };
    for (final c in _fields) {
      c.clear();
    }
    widget.onAdd(d);
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('ADD BY PRICE', style: DojiType.label)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in DrawingKind.values)
              DojiChoiceChip(
                label: k.label,
                selected: _kind == k,
                minHeight: DojiTokens.of(context).minTarget,
                onTap: () => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < names.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DojiTextField(
              controller: _fields[i],
              hint: names[i],
              semanticLabel: '${_kind.label} ${names[i]} price',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: i == names.length - 1 ? TextInputAction.done : TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => i == names.length - 1 ? _add() : null,
            ),
          ),
        DojiButton(
          label: 'add ${_kind.label}',
          variant: DojiButtonVariant.secondary,
          size: DojiButtonSize.small,
          onPressed: _values == null || widget.bars.isEmpty ? null : _add,
        ),
      ],
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../markets/domain/candle.dart';
import '../../domain/chart_viewport.dart';
import '../../domain/drawing.dart';
import '../../domain/drawing_drafts.dart';
import '../../domain/hit_test.dart';
import 'chart_painter.dart';

enum _Mode { none, pan, zoom, create, move, handle }

/// Design system: `ChartContainer` grown into doji's own chart (no third-party
/// chart): drag to pan, pinch or Ctrl + wheel to zoom, wheel to pan, hover or
/// long-press for the crosshair, and the drawing tools. The bars come from a
/// `BarSource` (live now, replay later); this widget only paints and reports
/// edits. Keys (tools, undo, delete, nudge) are handled by the screen.
class DojiChart extends StatefulWidget {
  const DojiChart({
    super.key,
    required this.bars,
    required this.timeframe,
    required this.decimals,
    required this.viewport,
    required this.drawings,
    required this.selectedId,
    required this.tool,
    required this.semanticLabel,
    required this.positionLabel,
    required this.timeLabel,
    required this.onViewport,
    required this.onCreate,
    required this.onChange,
    required this.onSelect,
  });

  final List<Candle> bars;
  final Timeframe timeframe;
  final int decimals;
  final ChartViewport viewport;
  final List<Drawing> drawings;
  final String? selectedId;

  /// The kind the next drag or tap draws; null = select and move.
  final DrawingKind? tool;
  final String semanticLabel;
  final String Function(Drawing d) positionLabel;
  final String Function(DateTime t) timeLabel;
  final ValueChanged<ChartViewport> onViewport;
  final ValueChanged<Drawing> onCreate;
  final ValueChanged<Drawing> onChange;
  final ValueChanged<String?> onSelect;

  @override
  State<DojiChart> createState() => _DojiChartState();
}

class _DojiChartState extends State<DojiChart> {
  Size _size = Size.zero;
  _Mode _mode = _Mode.none;
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  ChartViewport? _startViewport;
  ChartGeometry? _startGeometry;
  Hit? _hit;
  Drawing? _draft;
  Drawing? _preview;
  double _lastScale = 1;
  Offset? _crosshair;

  ChartGeometry _geometry([ChartViewport? v]) => ChartGeometry.of(
    viewport: v ?? widget.viewport,
    bars: widget.bars,
    timeframe: widget.timeframe,
    size: _size,
    axis: ChartPainter.axis,
  );

  double _span(ChartGeometry g) => (g.hi - g.lo) * 0.06;

  void _onScaleStart(ScaleStartDetails d) {
    _start = _last = d.localFocalPoint;
    _startViewport = widget.viewport;
    final g = _startGeometry = _geometry();
    _draft = _preview = null;
    _lastScale = 1;
    if (d.pointerCount > 1) {
      _mode = _Mode.zoom;
    } else if (widget.tool != null) {
      _mode = _Mode.create;
    } else {
      _hit = hitTest(widget.drawings, g, d.localFocalPoint, selectedId: widget.selectedId);
      if (_hit != null) {
        widget.onSelect(_hit!.drawingId);
        _mode = _hit!.handle == null ? _Mode.move : _Mode.handle;
      } else {
        _mode = _Mode.pan;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final g = _startGeometry;
    if (g == null) return;
    _last = d.localFocalPoint;
    if (d.pointerCount > 1 || _mode == _Mode.zoom) {
      _mode = _Mode.zoom;
      final factor = d.scale / _lastScale;
      _lastScale = d.scale;
      final now = _geometry();
      final v = widget.viewport
          .zoom(factor, (d.localFocalPoint.dx / now.plot.width).clamp(0.0, 1.0), widget.bars.length)
          .pan(-d.focalPointDelta.dx / now.pitch, widget.bars.length);
      widget.onViewport(v);
      return;
    }
    switch (_mode) {
      case _Mode.pan:
        widget.onViewport(_startViewport!.pan(-(_last.dx - _start.dx) / g.pitch, widget.bars.length));
      case _Mode.create:
        setState(
          () => _draft = draftDrawing(
            widget.tool!,
            start: g.pointAt(_start),
            end: g.pointAt(_last),
            barStep: widget.timeframe.duration,
            span: _span(g),
            id: _draft?.id,
          ),
        );
      case _Mode.move:
        final from = g.pointAt(_start), to = g.pointAt(_last);
        final orig = widget.drawings.where((x) => x.id == _hit!.drawingId).firstOrNull;
        if (orig != null) {
          setState(() => _preview = orig.shifted(to.at.difference(from.at), to.price - from.price));
        }
      case _Mode.handle:
        final orig = widget.drawings.where((x) => x.id == _hit!.drawingId).firstOrNull;
        if (orig != null) setState(() => _preview = orig.withHandle(_hit!.handle!, g.pointAt(_last)));
      case _Mode.none || _Mode.zoom:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails _) {
    final g = _startGeometry;
    final tapped = (_last - _start).distance < 6;
    if (g != null) {
      switch (_mode) {
        case _Mode.create:
          widget.onCreate(
            tapped || _draft == null
                ? draftDrawing(
                    widget.tool!,
                    start: g.pointAt(_start),
                    barStep: widget.timeframe.duration,
                    span: _span(g),
                  )
                : _draft!,
          );
        case _Mode.move || _Mode.handle:
          if (!tapped && _preview != null) widget.onChange(_preview!);
        case _Mode.pan:
          if (tapped) widget.onSelect(null);
        case _Mode.none || _Mode.zoom:
          break;
      }
    }
    setState(() {
      _mode = _Mode.none;
      _draft = _preview = null;
      _hit = null;
      _startGeometry = null;
    });
  }

  /// A tap: draws the tool's default-sized drawing there, or selects what is
  /// under it (empty space clears the selection).
  void _onTapUp(TapUpDetails d) {
    final g = _geometry();
    if (widget.tool != null) {
      widget.onCreate(
        draftDrawing(
          widget.tool!,
          start: g.pointAt(d.localPosition),
          barStep: widget.timeframe.duration,
          span: _span(g),
        ),
      );
    } else {
      widget.onSelect(hitTest(widget.drawings, g, d.localPosition, selectedId: widget.selectedId)?.drawingId);
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final g = _geometry();
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (ctrl) {
      final factor = e.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15;
      widget.onViewport(
        widget.viewport.zoom(factor, (e.localPosition.dx / g.plot.width).clamp(0.0, 1.0), widget.bars.length),
      );
    } else {
      final delta = e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
      widget.onViewport(widget.viewport.pan(delta / g.pitch, widget.bars.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final d in widget.drawings)
        if (_preview != null && d.id == _preview!.id) _preview! else d,
    ];
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _size = constraints.biggest;
            return MouseRegion(
              cursor: widget.tool != null ? SystemMouseCursors.precise : SystemMouseCursors.basic,
              onHover: (e) => setState(() => _crosshair = e.localPosition),
              onExit: (_) => setState(() => _crosshair = null),
              child: Listener(
                onPointerSignal: _onSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTapUp,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onLongPressStart: (d) => setState(() => _crosshair = d.localPosition),
                  onLongPressMoveUpdate: (d) => setState(() => _crosshair = d.localPosition),
                  onLongPressEnd: (_) => setState(() => _crosshair = null),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: ChartPainter(
                      geometry: _geometry(),
                      decimals: widget.decimals,
                      drawings: shown,
                      selectedId: widget.selectedId,
                      positionLabel: widget.positionLabel,
                      timeLabel: widget.timeLabel,
                      draft: _draft,
                      crosshair: _crosshair,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

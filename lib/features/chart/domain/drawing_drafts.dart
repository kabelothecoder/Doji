import 'package:uuid/uuid.dart';

import 'drawing.dart';

String newDrawingId() => 'drawing_${const Uuid().v4()}';

/// A new drawing of [kind] dragged from [start] to [end]. [barStep] is one bar
/// of the current timeframe; [span] a sensible height in price (a slice of the
/// visible range), used where the drag gives none.
Drawing draftDrawing(
  DrawingKind kind, {
  required ChartPoint start,
  ChartPoint? end,
  required Duration barStep,
  required double span,
  String? id,
}) {
  final drawingId = id ?? newDrawingId();
  final dragged = end != null && end.at != start.at && end.price != start.price;
  switch (kind) {
    case DrawingKind.level:
      return Drawing(id: drawingId, kind: kind, a: start);
    case DrawingKind.zone:
      return Drawing(
        id: drawingId,
        kind: kind,
        a: dragged ? start : ChartPoint(start.at, start.price + span),
        b: dragged ? end : ChartPoint(start.at.add(barStep * 10), start.price - span),
      );
    case DrawingKind.trendLine:
      return Drawing(
        id: drawingId,
        kind: kind,
        a: start,
        b: dragged ? end : ChartPoint(start.at.add(barStep * 10), start.price + span),
      );
    case DrawingKind.position:
      // The drag sets the stop; the target starts at 2R and the trader moves it.
      final stop = dragged ? end.price : start.price - span;
      final risk = start.price - stop;
      final right = dragged && end.at.isAfter(start.at.add(barStep * 5))
          ? end.at
          : start.at.add(barStep * 12);
      return Drawing(
        id: drawingId,
        kind: kind,
        a: start,
        b: ChartPoint(right, start.price),
        stop: stop,
        target: start.price + 2 * risk,
      );
  }
}

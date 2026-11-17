import 'dart:math' as math;
import 'dart:ui';

import 'chart_viewport.dart';
import 'drawing.dart';

/// What a pointer landed on: a drawing, and a handle of it (null = its body,
/// which moves the whole drawing).
class Hit {
  const Hit(this.drawingId, [this.handle]);

  final String drawingId;
  final DrawingHandle? handle;

  @override
  bool operator ==(Object other) => other is Hit && other.drawingId == drawingId && other.handle == handle;

  @override
  int get hashCode => Object.hash(drawingId, handle);

  @override
  String toString() => 'Hit($drawingId, $handle)';
}

/// The handles a drawing shows when selected, in pixels.
Map<DrawingHandle, Offset> handlesOf(Drawing d, ChartGeometry g) {
  final a = g.offsetOf(d.a);
  return switch (d.kind) {
    DrawingKind.level => {DrawingHandle.a: Offset(g.plot.width - 24, a.dy)},
    DrawingKind.zone || DrawingKind.trendLine => {DrawingHandle.a: a, DrawingHandle.b: g.offsetOf(d.b!)},
    DrawingKind.position => {
      DrawingHandle.a: a,
      DrawingHandle.b: Offset(g.xOf(d.b!.at), a.dy),
      DrawingHandle.stop: Offset(a.dx, g.yOf(d.stop!)),
      DrawingHandle.target: Offset(a.dx, g.yOf(d.target!)),
    },
  };
}

/// The top-most drawing under [p] (later drawings are on top), handles
/// first. [tolerance] is in pixels: 12 suits a finger and a mouse.
Hit? hitTest(List<Drawing> drawings, ChartGeometry g, Offset p, {double tolerance = 12, String? selectedId}) {
  // The selected drawing's handles win, so a handle on top of another drawing still grabs.
  if (selectedId != null) {
    final sel = drawings.where((d) => d.id == selectedId).firstOrNull;
    if (sel != null) {
      for (final MapEntry(:key, :value) in handlesOf(sel, g).entries) {
        if ((value - p).distance <= tolerance) return Hit(sel.id, key);
      }
    }
  }
  for (final d in drawings.reversed) {
    for (final MapEntry(:key, :value) in handlesOf(d, g).entries) {
      if ((value - p).distance <= tolerance) return Hit(d.id, key);
    }
    if (_onBody(d, g, p, tolerance)) return Hit(d.id);
  }
  return null;
}

bool _onBody(Drawing d, ChartGeometry g, Offset p, double tol) {
  final a = g.offsetOf(d.a);
  switch (d.kind) {
    case DrawingKind.level:
      return p.dx <= g.plot.width && (p.dy - a.dy).abs() <= tol;
    case DrawingKind.trendLine:
      return _distanceToSegment(p, a, g.offsetOf(d.b!)) <= tol;
    case DrawingKind.zone:
      return Rect.fromPoints(a, g.offsetOf(d.b!)).inflate(tol / 2).contains(p);
    case DrawingKind.position:
      final x2 = g.xOf(d.b!.at);
      final ys = [g.yOf(d.stop!), g.yOf(d.target!)];
      return Rect.fromLTRB(
        math.min(a.dx, x2),
        ys.reduce(math.min),
        math.max(a.dx, x2),
        ys.reduce(math.max),
      ).inflate(tol / 2).contains(p);
  }
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

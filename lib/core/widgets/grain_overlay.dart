import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Handoff fallback: "#050607 with 3% grain" (`GrainOverlay`).
///
/// Deterministic noise drawn once into a 160px tile and repeated, so goldens
/// are stable and no image asset is needed.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.opacity = 0.03});

  /// 3% on onboarding, 5% on auth screens.
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(painter: _GrainPainter(opacity), size: Size.infinite),
      ),
    ),
  );
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.opacity);

  final double opacity;
  static const _tile = 160.0;
  static final Float32List _points = _makePoints();

  static Float32List _makePoints() {
    final rnd = math.Random(7);
    const n = 2600;
    final list = Float32List(n * 2);
    for (var i = 0; i < n; i++) {
      list[i * 2] = rnd.nextDouble() * _tile;
      list[i * 2 + 1] = rnd.nextDouble() * _tile;
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Two passes, light and dark specks, approximate fractal noise at 3%.
    final light = Paint()
      ..color = Color.fromRGBO(255, 255, 255, (opacity * 2.2).clamp(0, 1))
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    for (double y = 0; y < size.height; y += _tile) {
      for (double x = 0; x < size.width; x += _tile) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawRawPoints(ui.PointMode.points, _points, light);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.opacity != opacity;
}

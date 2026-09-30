// Exports the launcher-icon and splash PNGs from assets/svg/doji-app-icon.svg.
//
//   flutter test tool/export_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Lives under tool/ so `flutter test` (which runs test/) never rewrites the
// assets by accident. Uses Flutter's own renderer, so no Inkscape/resvg needed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/svg/doji-app-icon.svg';
const _viewBox = 112.0;

/// The stand-in's full-bleed background. The adaptive-icon foreground drops
/// it (Android paints #0F1113 as the adaptive background instead). A real
/// icon delivery should include a separate foreground SVG.
const _backgroundRect = '<rect width="112" height="112" fill="#0F1113"/>';

Future<void> _png(String path, int size, void Function(Canvas c) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${size}x$size)');
}

/// Draws the S0 tile: rounded 26/112, inset white-8% hairline.
void _tile(Canvas c, ui.Picture icon, Offset origin, double side) {
  final scale = side / _viewBox;
  final rrect = RRect.fromRectAndRadius(origin & Size.square(side), Radius.circular(26 * scale));
  c.save();
  c.clipRRect(rrect);
  c.translate(origin.dx, origin.dy);
  c.scale(scale);
  c.drawPicture(icon);
  c.restore();
  c.drawRRect(
    rrect.deflate(scale / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale
      ..color = const Color(0x14FFFFFF),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export brand PNGs', () async {
    final raw = File(_source).readAsStringSync();
    final icon = (await vg.loadPicture(SvgStringLoader(raw), null)).picture;
    final glyphOnly = (await vg.loadPicture(
      SvgStringLoader(raw.replaceFirst(_backgroundRect, '')),
      null,
    )).picture;

    // Store master: square, full bleed. iOS/Android apply their own masks.
    await _png('assets/icon/app_icon.png', 1024, (c) {
      c.scale(1024 / _viewBox);
      c.drawPicture(icon);
    });

    // Android adaptive foreground: the 108dp canvas shows the middle 72dp.
    await _png('assets/icon/app_icon_foreground.png', 1024, (c) {
      const visible = 1024 * 72 / 108;
      c.translate((1024 - visible) / 2, (1024 - visible) / 2);
      c.scale(visible / _viewBox);
      c.drawPicture(glyphOnly);
    });

    // Native splash (iOS + Android < 12): the 112pt tile at 4x.
    await _png('assets/splash/splash_icon.png', 448, (c) => _tile(c, icon, Offset.zero, 448));

    // Android 12+: 1152px canvas = 240dp; the icon circle is 160dp. The tile
    // stays 112dp (537.6px) and fits inside the circle mask.
    await _png('assets/splash/splash_icon_android12.png', 1152, (c) {
      const side = 112 * 4.8;
      _tile(c, icon, const Offset((1152 - side) / 2, (1152 - side) / 2), side);
    });
  });
}

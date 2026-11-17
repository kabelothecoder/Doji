// Doji Share Card: story 1080×1920 / post 1080×1080, saved or shared as a PNG.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/me/presentation/share_card_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';

class _Out implements ImageOut {
  final saved = <(Uint8List, String)>[];
  final shared = <(Uint8List, String)>[];

  @override
  Future<bool> save(Uint8List png, String name) async {
    saved.add((png, name));
    return true;
  }

  @override
  Future<void> share(Uint8List png, String name) async => shared.add((png, name));
}

Future<(int, int)> _size(Uint8List png) async {
  final f = await (await ui.instantiateImageCodec(png)).getNextFrame();
  return (f.image.width, f.image.height);
}

void main() {
  testWidgets('me → share: story and post render at full size; save and share hand over a PNG', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final out = _Out();
      final h = await AppHarness.pump(
        tester,
        at: Routes.me,
        overrides: [imageOutProvider.overrideWithValue(out)],
      );
      await h.tap(find.text('share').first);
      expect(h.location, Routes.shareCard);
      expect(find.text('never shown: profit, balance, lot sizes'), findsOneWidget);
      expect(find.text('every square is a day i kept my word.'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('save image'));
        for (var i = 0; i < 20 && out.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(out.saved.single.$2, 'doji-grid-story.png');
      expect(await tester.runAsync(() => _size(out.saved.single.$1)), (1080, 1920));
      await h.wait();
      expect(find.textContaining('saved.', findRichText: true), findsOneWidget);

      await h.tapText('post · 1:1');
      expect(find.text('every square is a day i kept my word.'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text('share').last);
        for (var i = 0; i < 20 && out.shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(out.shared.single.$2, 'doji-grid-post.png');
      expect(await tester.runAsync(() => _size(out.shared.single.$1)), (1080, 1080));
    });
  });
}

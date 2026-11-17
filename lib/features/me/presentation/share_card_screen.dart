import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_controller.dart';
import '../../journal/presentation/journal_controller.dart';
import '../domain/me.dart';
import 'me_screen.dart';

enum ShareFormat { story, post }

/// Where the PNG goes. Overridden in tests.
abstract interface class ImageOut {
  /// True when the file was saved (false = the trader cancelled).
  Future<bool> save(Uint8List png, String name);
  Future<void> share(Uint8List png, String name);
}

class DeviceImageOut implements ImageOut {
  @override
  Future<bool> save(Uint8List png, String name) async =>
      await FilePicker.saveFile(fileName: name, bytes: png) != null;

  @override
  Future<void> share(Uint8List png, String name) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: name)],
    ),
  );
}

final imageOutProvider = Provider<ImageOut>((ref) => DeviceImageOut());

/// Share your grid (design: Doji Me Phone › share). Story 1080×1920 or post
/// 1080×1080 (Doji Share Card), rendered at full size and scaled to fit.
/// Never shows money: no profit, balance or lot sizes.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _card = GlobalKey();
  var _format = ShareFormat.story;
  String? _status;
  var _busy = false;

  String get _fileName => 'doji-grid-${_format.name}.png';

  Future<Uint8List?> _png() async {
    final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // The boundary is laid out at 1080 wide, so pixel ratio 1 = a 1080px image.
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _run(Future<String?> Function(Uint8List png) out) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? status;
    try {
      final png = await _png();
      status = png == null ? "couldn't make the image. try again." : await out(png);
    } catch (_) {
      status = "couldn't make the image. try again.";
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _status = status;
      });
    }
  }

  void _save() =>
      unawaited(_run((png) async => await ref.read(imageOutProvider).save(png, _fileName) ? 'saved.' : null));

  void _share() => unawaited(
    _run((png) async {
      await ref.read(imageOutProvider).share(png, _fileName);
      return null;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(homeProfileProvider);
    final streak = keptStreak(keptDays(ref.watch(journalControllerProvider)));
    final rank = kRanks.firstWhere((r) => r.$1 == profile.rank, orElse: () => kRanks.first);
    final card = ShareCard(format: _format, name: profile.name ?? 'trader', rank: rank, streak: streak);

    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DojiButton(
                    label: 'cancel',
                    expand: false,
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.me),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'share your grid',
                        textAlign: TextAlign.center,
                        style: DojiType.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DojiColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final f in ShareFormat.values)
                    Expanded(
                      child: DojiChoiceChip(
                        label: f == ShareFormat.story ? 'story · 9:16' : 'post · 1:1',
                        selected: _format == f,
                        onTap: () => setState(() {
                          _format = f;
                          _status = null;
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Semantics(
                    image: true,
                    label:
                        'share card preview: doji, ${profile.name ?? 'trader'}, your grid, rank ${rank.$1} ${rank.$2}, $streak-day streak',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(DojiRadius.card),
                        child: FittedBox(
                          child: RepaintBoundary(key: _card, child: card),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _Line(
                icon: Icons.check,
                color: DojiColors.dojiGreen,
                text: 'logo, name, grid, rank, streak',
              ),
              const SizedBox(height: 6),
              const _Line(
                icon: Icons.lock_outline,
                color: DojiColors.textSecondary,
                text: 'never shown: profit, balance, lot sizes',
              ),
              if (_status case final s?) ...[const SizedBox(height: 10), TerminalLine(s)],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DojiButton(
                      label: 'save image',
                      variant: DojiButtonVariant.outline,
                      onPressed: _busy ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DojiButton(
                      label: 'share',
                      icon: const Icon(Icons.ios_share, size: 20),
                      onPressed: _busy ? null : _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text, style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
      ),
    ],
  );
}

/// Design: `Doji Share Card` at full size (1080 wide). Story adds the closing line.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.format,
    required this.name,
    required this.rank,
    required this.streak,
  });

  final ShareFormat format;
  final String name;
  final (String, String) rank;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final story = format == ShareFormat.story;
    final mono = DojiType.data.copyWith(color: DojiColors.textSecondary);
    final handle = Text(name, style: mono.copyWith(fontSize: story ? 48 : 40));
    return MediaQuery(
      // The image never follows the device's text size.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: 1080,
        height: story ? 1920 : 1080,
        color: DojiColors.bg,
        padding: EdgeInsets.all(story ? 96 : 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DojiAppIcon(size: 96),
                const SizedBox(width: 28),
                Text('doji', style: DojiType.title.copyWith(fontSize: 64)),
                if (!story) ...[const Spacer(), handle],
              ],
            ),
            if (story) ...[const Spacer(), handle],
            SizedBox(height: story ? 48 : 40),
            YearHalf(
              label: 'jan – jun',
              first: true,
              gap: story ? 7 : 6,
              labelGap: 14,
              labelStyle: mono.copyWith(fontSize: 26),
            ),
            SizedBox(height: story ? 56 : 32),
            YearHalf(
              label: 'jul – dec',
              first: false,
              gap: story ? 7 : 6,
              labelGap: 14,
              labelStyle: mono.copyWith(fontSize: 26),
            ),
            SizedBox(height: story ? 48 : 40),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DojiRadius.pill),
                    border: Border.all(color: DojiColors.textPrimary, width: 3),
                  ),
                  child: Text(rank.$1, style: DojiType.data.copyWith(fontSize: 44)),
                ),
                const SizedBox(width: 24),
                Text(rank.$2, style: DojiType.body.copyWith(fontSize: 40, color: DojiColors.textSecondary)),
                const Spacer(),
                Text('$streak-day streak', style: DojiType.data.copyWith(fontSize: 44)),
              ],
            ),
            if (story) ...[
              const Spacer(),
              Text(
                'every square is a day i kept my word.',
                style: DojiType.body.copyWith(fontSize: 40, height: 1.35, color: DojiColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

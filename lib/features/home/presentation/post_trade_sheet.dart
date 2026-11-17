import 'dart:async';

import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../mood/data/mood_repository.dart';
import '../../mood/domain/mood.dart';
import '../../mood/presentation/mood_screen.dart' show FeelingChips;
import 'home_controller.dart';

/// Post-trade emotion check (Doji Home Phone: postTrade): "how did that
/// trade feel?", before or after, intensity 1–10, save or skip.
///
/// Shown from Home's "log a trade" and the rail's "log emotion".
/// TODO(next-slice): [instrument] and the trade come from the imported trade.
Future<void> showPostTradeSheet(BuildContext context, {String instrument = 'XAUUSD'}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (_) => PostTradeSheet(instrument: instrument),
  );
}

class PostTradeSheet extends ConsumerStatefulWidget {
  const PostTradeSheet({super.key, required this.instrument});

  final String instrument;

  @override
  ConsumerState<PostTradeSheet> createState() => _PostTradeSheetState();
}

class _PostTradeSheetState extends ConsumerState<PostTradeSheet> {
  EmotionWhen _when = EmotionWhen.after;
  double _intensity = 6;
  String? _feeling;

  void _save() {
    final feeling = _feeling;
    if (feeling == null) return;
    unawaited(ref.read(hapticsProvider).light());
    final after = _when == EmotionWhen.after;
    unawaited(
      ref
          .read(moodControllerProvider.notifier)
          .log(
            feeling: feeling,
            moment: after ? MoodMoment.afterTrade : MoodMoment.beforeTrade,
            intensity: _intensity.round(),
            // After: the trade just logged. Before: there is no trade yet.
            tradeId: after ? latestTradeToday(ref.read(activeAccountTradesProvider), clock.now()) : null,
          ),
    );
    ref.read(homeControllerProvider.notifier).logEmotion(_when, _intensity.round(), feeling: feeling);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'how did that trade feel?',
        child: GlassSurface(
          radius: DojiRadius.sheet,
          tint: DojiColors.elevated2,
          fillOpacity: 0.8,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3D42),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TerminalLine(
                          'trade logged · ${instrumentLabel(widget.instrument)}',
                          liveRegion: false,
                          style: DojiType.hint,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(10, 0),
                        child: DojiIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'close',
                          outlined: false,
                          background: Colors.transparent,
                          foreground: DojiColors.textSecondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    header: true,
                    child: Text('how did that trade feel?', style: DojiType.title.copyWith(fontSize: 24)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in EmotionWhen.values)
                        DojiChoiceChip(
                          label: '${w.name} the trade',
                          selected: _when == w,
                          exclusive: true,
                          style: DojiChoiceStyle.chip,
                          onTap: () => setState(() => _when = w),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FeelingChips(selected: _feeling, onPick: (f) => setState(() => _feeling = f)),
                  const SizedBox(height: 14),
                  DojiSlider(
                    label: 'intensity',
                    value: _intensity,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    format: (v) => '${v.round()}/10',
                    onChanged: (v) => setState(() => _intensity = v),
                  ),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        Text('1 · barely', style: DojiType.hint.copyWith(fontSize: 11)),
                        const Spacer(),
                        Text('10 · overwhelming', style: DojiType.hint.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DojiButton(label: 'save', onPressed: _feeling == null ? null : _save),
                  DojiButton(
                    label: 'skip',
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

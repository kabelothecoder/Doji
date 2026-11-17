import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../markets/domain/candle.dart';
import '../../markets/presentation/brief_chat_controller.dart' show ChatVoice;
import '../../onboarding/data/voice_input.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';
import '../domain/copilot.dart';
import 'chart_controller.dart';
import 'widgets/chart_sheet.dart';

/// "what is this?" after a drawing is finished: the trader's reason in their
/// own words (typed, or dictated where the plan includes voice, as on the
/// coach), then the co-pilot's one line back. "skip" keeps the drawing with
/// no reason and asks nothing.
Future<void> showWhatIsThis(
  BuildContext context, {
  required ChartKey symbol,
  required String noteId,
  required String drawingName,
  required List<Candle> bars,
}) => showChartSheet<void>(
  context,
  label: 'what is this?',
  builder: (_) => WhatIsThisSheet(symbol: symbol, noteId: noteId, drawingName: drawingName, bars: bars),
);

class WhatIsThisSheet extends ConsumerStatefulWidget {
  const WhatIsThisSheet({
    super.key,
    required this.symbol,
    required this.noteId,
    required this.drawingName,
    required this.bars,
  });

  final ChartKey symbol;
  final String noteId;
  final String drawingName;
  final List<Candle> bars;

  @override
  ConsumerState<WhatIsThisSheet> createState() => _WhatIsThisSheetState();
}

class _WhatIsThisSheetState extends ConsumerState<WhatIsThisSheet> {
  final _text = TextEditingController();
  late ChatVoice _voice;
  bool _listening = false;
  bool _thinking = false;
  bool _prepared = false;
  CopilotReply? _reply;

  @override
  void initState() {
    super.initState();
    final v = ref.read(voiceInputProvider);
    _voice = !v.mightBeAvailable
        ? ChatVoice.device
        : includesVoiceCoach(ref.read(entitlementProvider).plan)
        ? ChatVoice.available
        : ChatVoice.plan;
  }

  @override
  void dispose() {
    if (_listening) unawaited(ref.read(voiceInputProvider).stop());
    _text.dispose();
    super.dispose();
  }

  Future<void> _mic() async {
    final voice = ref.read(voiceInputProvider);
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_prepared) {
      final a = await voice.prepare();
      if (!mounted) return;
      if (a != VoiceAvailability.available) {
        setState(
          () => _voice = a == VoiceAvailability.permissionDenied ? ChatVoice.microphone : ChatVoice.device,
        );
        return;
      }
      _prepared = true;
    }
    setState(() => _listening = true);
    await voice.start(
      onResult: (words, _) {
        if (mounted) setState(() => _text.text = words);
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  Future<void> _send() async {
    final words = _text.text.trim();
    if (words.isEmpty || _thinking) return;
    if (_listening) await _mic();
    setState(() => _thinking = true);
    final reply = await ref
        .read(chartControllerProvider(widget.symbol).notifier)
        .explain(widget.noteId, words, bars: widget.bars);
    if (mounted) {
      setState(() {
        _thinking = false;
        _reply = reply;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;
    final notice = switch (_voice) {
      ChatVoice.available => null,
      ChatVoice.plan => 'voice comes with pro trader. type yours below.',
      ChatVoice.device => "voice isn't on this ${PlatformInfo.deviceNoun} yet. type yours below.",
      ChatVoice.microphone => 'the microphone is off for doji. type here, or turn it on in settings.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('what is this?', style: DojiType.headline)),
        const SizedBox(height: 4),
        Text(widget.drawingName, style: DojiType.hint),
        const SizedBox(height: 12),
        if (reply == null) ...[
          Text('say why you marked it, in your own words.', style: DojiType.callout.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          DojiTextField(
            controller: _text,
            hint: 'order block on the 15m',
            minLines: 2,
            maxLines: 4,
            semanticLabel: 'your reason for this mark',
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => unawaited(_send()),
            onChanged: (_) => setState(() {}),
            trailing: _voice == ChatVoice.available
                ? DojiIconButton(
                    icon: _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    semanticLabel: _listening ? 'stop listening' : 'say it instead',
                    onPressed: () => unawaited(_mic()),
                  )
                : null,
          ),
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(notice, style: DojiType.hint),
            if (_voice == ChatVoice.plan)
              Align(
                alignment: Alignment.centerLeft,
                child: DojiButton(
                  label: 'see pro trader',
                  variant: DojiButtonVariant.ghost,
                  size: DojiButtonSize.small,
                  expand: false,
                  onPressed: () => context.push('${Routes.plans}?plan=${PlanId.pro.name}'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (_thinking)
            const TerminalLine('holding it up against your rules', cursor: true)
          else ...[
            DojiButton(
              label: 'save my reason',
              onPressed: _text.text.trim().isEmpty ? null : () => unawaited(_send()),
            ),
            const SizedBox(height: 8),
            DojiButton(
              label: 'skip',
              variant: DojiButtonVariant.text,
              size: DojiButtonSize.small,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ] else ...[
          Text('you', style: DojiType.label),
          const SizedBox(height: 4),
          Text(_text.text.trim(), style: DojiType.body),
          const SizedBox(height: 16),
          Text('doji', style: DojiType.label),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(reply.text, style: DojiType.aiOutput.copyWith(color: DojiColors.textPrimary)),
          ),
          if (reply.crisis) ...[
            const SizedBox(height: 12),
            DojiButton(
              label: 'talk to the coach',
              variant: DojiButtonVariant.secondary,
              size: DojiButtonSize.small,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.coach);
              },
            ),
          ],
          const SizedBox(height: 16),
          DojiButton(
            label: 'done',
            variant: DojiButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}

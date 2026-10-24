import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/domain/user_zone.dart';
import '../../plans/domain/plans.dart';
import '../domain/market_format.dart';
import '../domain/pair_brief.dart';
import 'brief_chat_controller.dart';
import 'pair_detail_controller.dart';
import 'widgets/follow_up_chip.dart';

/// Handoff 1b: "the follow-up bar opens a chat sheet scoped to this brief".
/// iOS: a detented glass sheet. Android and Windows: a Material modal bottom
/// sheet, title left-aligned. [ask] sends a suggested question straight away;
/// [listen] opens the mic (or the keyboard, with the reason voice is off).
Future<void> showBriefChatSheet(
  BuildContext context, {
  required String symbol,
  String? ask,
  bool listen = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (_) => BriefChatSheet(symbol: symbol, ask: ask, listen: listen),
  );
}

class BriefChatSheet extends ConsumerStatefulWidget {
  const BriefChatSheet({super.key, required this.symbol, this.ask, this.listen = false});

  final String symbol;
  final String? ask;
  final bool listen;

  @override
  ConsumerState<BriefChatSheet> createState() => _BriefChatSheetState();
}

class _BriefChatSheetState extends ConsumerState<BriefChatSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The mic was asked for but voice is off: say why.
  bool _wantedVoice = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = ref.read(briefChatControllerProvider(widget.symbol).notifier);
      final ask = widget.ask;
      if (ask != null) {
        unawaited(c.send(ask));
      } else if (widget.listen) {
        if (ref.read(briefChatControllerProvider(widget.symbol)).voice == ChatVoice.available) {
          unawaited(c.toggleMic());
        } else {
          setState(() => _wantedVoice = true);
          _focus.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final words = _text.text.trim();
    if (words.isEmpty) return;
    unawaited(ref.read(briefChatControllerProvider(widget.symbol).notifier).send(words));
    _text.clear();
  }

  Future<void> _close() async {
    await ref.read(briefChatControllerProvider(widget.symbol).notifier).end();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(briefChatControllerProvider(widget.symbol));
    final c = ref.read(briefChatControllerProvider(widget.symbol).notifier);
    final brief = ref.watch(pairBriefProvider(widget.symbol)).value;
    final zone = userZoneFromProfile(ref.watch(marketsProfileProvider));
    final ios = PlatformInfo.isIOS;
    final name = displaySymbol(widget.symbol);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    Widget content(ScrollController scroll) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ios)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(color: DojiColors.separator, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              if (ios) const SizedBox(width: 44),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'ask about this brief',
                    textAlign: ios ? TextAlign.center : TextAlign.start,
                    style: DojiType.headline.copyWith(fontSize: 17),
                  ),
                ),
              ),
              DojiIconButton(
                icon: Icons.close_rounded,
                semanticLabel: 'close',
                outlined: false,
                background: Colors.transparent,
                onPressed: _close,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              Text(
                brief == null
                    ? 'scoped to your $name brief'
                    : 'scoped to your $name brief · updated ${clockTime(zone, brief.updatedAt)}',
                style: DojiType.hint,
              ),
              const SizedBox(height: 16),
              for (final t in s.turns) ...[_Turn(t), const SizedBox(height: 14)],
              if (s.listening) ...[
                Semantics(
                  liveRegion: true,
                  child: Text('LISTENING…', style: DojiType.label.copyWith(letterSpacing: 1.2)),
                ),
                if (s.heard.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(s.heard, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
                ],
                const SizedBox(height: 14),
              ],
              if (s.thinking)
                Semantics(
                  liveRegion: true,
                  child: Text('THINKING…', style: DojiType.label.copyWith(letterSpacing: 1.2)),
                ),
              if (s.missedWords)
                const TerminalLine("didn't catch that. tap the mic and speak.", tone: TerminalTone.primary),
              if (_wantedVoice || s.voice == ChatVoice.microphone) _VoiceNotice(voice: s.voice),
              if (s.turns.isEmpty && !s.thinking && brief != null && brief.followUps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in brief.followUps) FollowUpChip(label: q, onPressed: () => c.send(q)),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + insets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DojiTextField(
                controller: _text,
                focusNode: _focus,
                large: false,
                hint: 'ask about this brief',
                semanticLabel: 'question about this brief',
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.voice == ChatVoice.available) ...[
                      DojiIconButton(
                        icon: s.listening ? Icons.stop_rounded : Icons.mic_rounded,
                        semanticLabel: s.listening ? 'send what you said' : 'ask by voice',
                        filled: s.listening,
                        onPressed: s.thinking ? null : c.toggleMic,
                      ),
                      const SizedBox(width: 6),
                    ],
                    DojiIconButton(
                      icon: Icons.arrow_upward_rounded,
                      semanticLabel: 'send',
                      filled: true,
                      background: _text.text.trim().isEmpty ? DojiColors.elevated2 : null,
                      foreground: _text.text.trim().isEmpty ? DojiColors.textSecondary : null,
                      onPressed: _text.text.trim().isEmpty || s.thinking ? null : _send,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Measured against your strategy. Not financial advice.',
                textAlign: TextAlign.center,
                style: DojiType.callout.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.62],
      builder: (context, scroll) => ios
          ? GlassSurface(
              radius: DojiRadius.sheet,
              tint: DojiColors.elevated1,
              fillOpacity: 0.86,
              child: content(scroll),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: DojiColors.elevated1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DojiRadius.sheet)),
              ),
              child: content(scroll),
            ),
    );
  }
}

/// One line of the chat: yours in plain text, doji's after a green `>`.
class _Turn extends StatelessWidget {
  const _Turn(this.turn);

  final BriefTurn turn;

  @override
  Widget build(BuildContext context) => turn.fromYou
      ? Semantics(
          label: 'you: ${turn.text}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOU', style: DojiType.label.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Text(turn.text, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
              ],
            ),
          ),
        )
      : Semantics(
          liveRegion: true,
          label: 'doji: ${turn.text}',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: DojiType.aiOutput.copyWith(color: DojiColors.textPrimary),
                children: [
                  const TextSpan(
                    text: '> ',
                    style: TextStyle(color: DojiColors.dojiGreen),
                  ),
                  TextSpan(text: turn.text),
                ],
              ),
            ),
          ),
        );
}

/// Why the question is typed: the plan, the device or the microphone.
class _VoiceNotice extends StatelessWidget {
  const _VoiceNotice({required this.voice});

  final ChatVoice voice;

  @override
  Widget build(BuildContext context) {
    final text = switch (voice) {
      ChatVoice.available => null,
      ChatVoice.plan => 'voice questions come with pro trader. type yours below.',
      ChatVoice.device => "voice isn't on this ${PlatformInfo.deviceNoun} yet. type your question below.",
      ChatVoice.microphone => 'the microphone is off for doji. type here, or turn it on in settings.',
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(liveRegion: true, child: Text(text, style: DojiType.callout.copyWith(fontSize: 13))),
          if (voice == ChatVoice.plan)
            DojiButton(
              label: 'see pro trader',
              variant: DojiButtonVariant.ghost,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: () => context.push('${Routes.plans}?plan=${PlanId.pro.name}'),
            ),
        ],
      ),
    );
  }
}

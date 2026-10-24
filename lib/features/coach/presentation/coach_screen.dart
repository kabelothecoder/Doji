import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/platform/layout.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../plans/domain/plans.dart';
import 'coach_controller.dart';
import 'save_session_sheet.dart';
import 'widgets/coach_text_input.dart';
import 'widgets/live_transcript.dart';
import 'widgets/push_to_talk_button.dart';
import 'widgets/voice_picker.dart';

/// Handoff 1c `CoachScreen` (Doji Hero Screens): a full-screen cover over the
/// tabs. Voice picker, the live transcript, the orb, then save · push-to-talk
/// · end, and the "coaching, not therapy" line.
///
/// Close, end and the back gesture all ask to save first when something you
/// said is unsaved. iOS: pull down to close. Windows: Esc closes.
///
/// [listen]: opened by a long-press on the coach orb, so the mic opens
/// straight away (or the text field takes focus).
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.listen = false});

  final bool listen;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  Timer? _tick;
  bool _leaving = false;

  /// Set once leaving is decided, so the route may pop.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // The session clock.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(coachControllerProvider.notifier).start(listen: widget.listen);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving || _closing) return;
    _leaving = true;
    try {
      final c = ref.read(coachControllerProvider.notifier);
      await c.end();
      if (!mounted) return;
      if (ref.read(coachControllerProvider).unsaved) {
        final choice = await showSaveSessionSheet(context);
        if (!mounted || choice == null) return;
        if (choice == LeaveChoice.save) await c.save();
        if (!mounted) return;
      }
      setState(() => _closing = true);
      // Pop once the PopScope below has let go.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.canPop() ? context.pop() : context.go(Routes.home);
      });
    } finally {
      _leaving = false;
    }
  }

  Future<void> _save() async {
    await ref.read(coachControllerProvider.notifier).save();
    unawaited(ref.read(hapticsProvider).light());
  }

  /// iOS: pulling the cover down past the top closes it.
  bool _onScroll(ScrollUpdateNotification n) {
    if (PlatformInfo.isIOS && n.dragDetails != null && n.metrics.pixels < -80) _leave();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(coachControllerProvider);
    final c = ref.read(coachControllerProvider.notifier);
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final target = DojiTokens.of(context).minTarget;
    final voice = s.mode == CoachInputMode.voice;
    final orbLabel = s.thinking
        ? 'THINKING…'
        : switch (s.orb) {
            VoiceOrbState.idle => 'READY',
            VoiceOrbState.listening => 'LISTENING…',
            VoiceOrbState.speaking => 'COACH IS SPEAKING',
          };

    return PopScope(
      canPop: _closing || !s.unsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _leave},
        child: Scaffold(
          backgroundColor: DojiColors.bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(margin, 12, margin, 0),
                              // Close left, the picker centred; at large text the
                              // picker drops below rather than shrinking its targets.
                              child: OverflowBar(
                                alignment: MainAxisAlignment.spaceBetween,
                                spacing: 8,
                                overflowSpacing: 8,
                                children: [
                                  _CloseButton(size: target, onPressed: _leave),
                                  VoicePicker(value: s.voice, onChanged: c.setVoice),
                                  SizedBox(width: target),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              child: LiveTranscript(
                                elapsed: clock.now().difference(s.startedAt),
                                turns: s.turns,
                                listening: s.orb == VoiceOrbState.listening,
                                heard: s.heard,
                                thinking: s.thinking,
                                speaking: s.orb == VoiceOrbState.speaking,
                                onCoachDone: c.doneSpeaking,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    VoiceOrb(state: s.orb, size: 200),
                                    const SizedBox(height: 12),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        orbLabel,
                                        textAlign: TextAlign.center,
                                        style: DojiType.label.copyWith(
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    _Notice(state: s, margin: margin),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: margin),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RoundControl(
                                    icon: s.saved
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                    label: s.saved ? 'saved' : 'save',
                                    semanticLabel: s.saved ? 'session saved' : 'save session',
                                    onPressed: s.hasYou && !s.saved ? _save : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: voice
                                        ? PushToTalkButton(
                                            state: s.orb,
                                            tapToSend: s.tapToSend,
                                            enabled: !s.thinking,
                                            onPress: c.press,
                                            onRelease: c.release,
                                          )
                                        : CoachTextInput(
                                            onSend: c.send,
                                            autofocus: widget.listen || isWideLayout(context),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  _RoundControl(
                                    icon: Icons.stop_outlined,
                                    label: 'end',
                                    semanticLabel: 'end session',
                                    onPressed: _leave,
                                  ),
                                ],
                              ),
                            ),
                            const _Footer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the orb's state: why this session is text, or that the mic heard
/// nothing. Never colour alone; plain words.
class _Notice extends StatelessWidget {
  const _Notice({required this.state, required this.margin});

  final CoachState state;
  final double margin;

  @override
  Widget build(BuildContext context) {
    final text = state.missedWords
        ? "didn't catch that. hold the button and speak."
        : switch (state.textReason) {
            TextReason.none => null,
            TextReason.device => "voice isn't on this ${PlatformInfo.deviceNoun} yet. type to your coach.",
            TextReason.plan => 'voice coaching comes with pro trader. text coaching is on.',
            TextReason.microphone => 'the microphone is off for doji. type here, or turn it on in settings.',
          };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 12, margin, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(text, textAlign: TextAlign.center, style: DojiType.callout.copyWith(fontSize: 13)),
          ),
          if (!state.missedWords && state.textReason == TextReason.plan)
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

/// The glass close button, top left.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onPressed,
    semanticLabel: 'close coach',
    borderRadius: BorderRadius.circular(size / 2),
    child: SizedBox.square(
      dimension: size,
      child: const GlassSurface(
        circle: true,
        blur: 24,
        tint: DojiColors.elevated2,
        fillOpacity: 0.7,
        child: Center(child: Icon(Icons.close_rounded, size: 22, color: DojiColors.textPrimary)),
      ),
    ),
  );
}

/// Save and end: a 56 circle with a mono label under it.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? DojiColors.textSecondary : DojiColors.textPrimary;
    return DojiPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      showPressedOverlay: false,
      borderRadius: BorderRadius.circular(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: DojiColors.elevated2.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: DojiColors.glassHairline),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, style: DojiType.hint.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
    child: Text.rich(
      TextSpan(
        style: DojiType.callout.copyWith(fontSize: 13, height: 1.5),
        children: [
          const TextSpan(text: 'coaching, not therapy. need someone now? SADAG '),
          TextSpan(
            text: '0800 567 567',
            style: DojiType.hint.copyWith(fontSize: 13, color: DojiColors.textPrimary),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}

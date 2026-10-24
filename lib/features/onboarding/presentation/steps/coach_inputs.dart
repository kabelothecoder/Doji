import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/onboarding_catalog.dart';
import '../../domain/onboarding_step.dart';
import '../../domain/sessions.dart';
import '../../domain/user_zone.dart';
import 'step_input.dart';

/// Handoff 5a: `VoiceCard(onPlay) × 3`, plus the coach name from the brief
/// (the handoff's own brief stopped before it; see design/SOURCE.md).
class CoachInput extends StatefulWidget {
  const CoachInput(this.args, {super.key});

  final StepInputArgs args;

  static const _seeds = {'calm_male': 3, 'calm_female': 9, 'coach_tone': 5};

  @override
  State<CoachInput> createState() => _CoachInputState();
}

class _CoachInputState extends State<CoachInput> {
  String? _playing;
  Timer? _stop;
  late final _name = TextEditingController(text: A.mapStr(widget.args.draft, 'name') ?? '');

  @override
  void dispose() {
    _stop?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _set(String key, Object? value) {
    final m = widget.args.draftMap;
    value == null ? m.remove(key) : m[key] = value;
    widget.args.onChanged(m);
  }

  /// Placeholder preview: animates the waveform for a moment, no audio yet.
  /// TODO(next-slice): play real voice lines (just_audio, ducking via audio_session).
  void _play(String voice) {
    _stop?.cancel();
    if (_playing == voice) {
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = voice);
    _stop = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final voice = A.mapStr(widget.args.draft, 'voice');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in voiceOptions) ...[
          VoiceCard(
            name: o.label,
            seed: CoachInput._seeds[o.value] ?? 1,
            selected: voice == o.value,
            playing: _playing == o.value,
            onSelect: () => _set('voice', o.value),
            onPlay: () => _play(o.value),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        Text('COACH NAME · OPTIONAL', style: DojiType.label.copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        DojiTextField(
          controller: _name,
          large: false,
          hint: 'doji',
          semanticLabel: 'coach name, optional',
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set('name', v.trim().isEmpty ? null : v.trim()),
          onSubmitted: (_) => widget.args.onSubmit(),
        ),
      ],
    );
  }
}

/// Handoff 5b (ASSUMED in the handoff): `DojiChoiceGrid(columns: 3) ·
/// permission_handler`. "Priming card first, then the OS prompt. 'not now'
/// keeps the ritual in-app only."
class RitualInput extends StatelessWidget {
  const RitualInput(this.args, {super.key});

  final StepInputArgs args;

  @override
  Widget build(BuildContext context) {
    final options = args.step.resolveOptions(args.answers);
    final time = A.mapStr(args.draft, 'time');
    final session = firstSession(
      A.list(args.answers, StepIds.sessions),
      userZoneFromAnswers(args.answers),
    )?.label.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EqualColumns(
          columns: 3,
          children: [
            for (var i = 0; i < options.length; i++)
              DojiChoiceChip(
                label: options[i].label,
                sub: options[i].sub,
                mono: true,
                center: true,
                exclusive: true,
                keyHint: '${i + 1}',
                minHeight: 64,
                textStyle: DojiType.data,
                selected: time == options[i].value,
                onTap: () => args.onChanged({...args.draftMap, 'time': options[i].value}),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassSurface(
          tint: DojiColors.elevated2,
          blur: 26,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: DojiColors.dojiGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'one nudge a day, before ${session ?? 'your session'}',
                      style: DojiType.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'plus a tilt check if you break your own rules. never about prices.',
                style: DojiType.callout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

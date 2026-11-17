import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/a11y/semantics_ext.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/condition_eval.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/home_models.dart';
import 'home_controller.dart';
import '../../mood/data/mood_repository.dart';
import '../../mood/domain/mood.dart';
import 'widgets/home_card.dart';

enum _OpenStep { mood, plan, pledge, brief, done }

/// The Open: 60 seconds before the market (Doji Home › 02). Mood, the plan
/// in the trader's words (research-intake-plan › 2b), rules pledge, today's line, done. Closing at any point goes back without
/// completing the open.
class OpenScreen extends ConsumerStatefulWidget {
  const OpenScreen({super.key});

  @override
  ConsumerState<OpenScreen> createState() => _OpenScreenState();
}

class _OpenScreenState extends ConsumerState<OpenScreen> {
  _OpenStep _step = _OpenStep.mood;

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.home);

  void _go(_OpenStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final index = _OpenStep.values.indexOf(_step);
    final progress = (index + 1).clamp(1, 4);
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, 12, margin, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: DojiTokens.of(context).minTarget,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-10, 0),
                          child: DojiIconButton(
                            icon: Icons.close_rounded,
                            semanticLabel: 'close',
                            outlined: false,
                            background: Colors.transparent,
                            foreground: DojiColors.textSecondary,
                            onPressed: _leave,
                          ),
                        ),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Row(
                              children: [
                                for (var i = 1; i <= 4; i++) ...[
                                  if (i > 1) const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: i <= progress ? DojiColors.dojiGreen : DojiColors.separator,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Semantics(
                          label: 'step $progress of 4',
                          child: Text('$progress/4', style: DojiType.hint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: switch (_step) {
                      _OpenStep.mood => _MoodStep(onNext: () => _go(_OpenStep.plan)),
                      _OpenStep.plan => _PlanStep(onRead: () => _go(_OpenStep.pledge)),
                      _OpenStep.pledge => _PledgeStep(onPledged: () => _go(_OpenStep.brief)),
                      _OpenStep.brief => _BriefStep(onReady: () => _go(_OpenStep.done)),
                      _OpenStep.done => _DoneStep(
                        onHome: () {
                          ref.read(homeControllerProvider.notifier).completeOpen();
                          _leave();
                        },
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.tag, required this.title, this.body});

  final String tag;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TerminalLine(tag, tone: TerminalTone.muted, liveRegion: false),
      const SizedBox(height: 10),
      Semantics(header: true, child: Text(title, style: DojiType.largeTitle.copyWith(fontSize: 32))),
      if (body != null) ...[
        const SizedBox(height: 10),
        Text(body!, style: DojiType.callout.copyWith(fontSize: 16)),
      ],
    ],
  );
}

class _MoodStep extends ConsumerWidget {
  const _MoodStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(homeControllerProvider.select((s) => s.mood));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(
                  tag: 'the open',
                  title: 'how are you walking in?',
                  body: "pick one. it's saved with today's trades.",
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final m in openMoods)
                      DojiChoiceChip(
                        label: m,
                        selected: mood == m,
                        exclusive: true,
                        style: DojiChoiceStyle.chip,
                        onTap: () {
                          unawaited(ref.read(hapticsProvider).tick());
                          ref.read(homeControllerProvider.notifier).pickMood(m);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DojiButton(
          label: 'continue',
          onPressed: mood == null
              ? null
              : () {
                  // The open asks no intensity.
                  unawaited(
                    ref.read(moodControllerProvider.notifier).log(feeling: mood, moment: MoodMoment.open),
                  );
                  onNext();
                },
        ),
      ],
    );
  }
}

/// The trader's own plan, read once before the session: their words, what doji measures, and
/// their lines for wrong, right and staying out.
class _PlanStep extends ConsumerWidget {
  const _PlanStep({required this.onRead});

  final VoidCallback onRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(homeProfileProvider);
    final s = p.strategy;
    final version = p.activeAccount?.strategyVersion;
    final lines = <(String, String)>[
      if (s?.rawText case final w? when w.trim().isNotEmpty) ('my setup', w),
      if (s?.wrongWhen case final w?) ("where i'm wrong", w),
      if (s?.rightWhen case final w?) ("where i'm right", w),
      if (s?.stayOutWhen case final w?) ("when i don't trade", w),
      if (s != null && s.conditions.isNotEmpty)
        ('doji measures', s.conditions.map(conditionLabel).join(' · ')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepHeader(
                  tag: version == null ? 'your plan' : 'your plan · version $version',
                  title: 'read it once.',
                  body: lines.isEmpty ? 'no plan written yet. add it in settings › accounts.' : null,
                ),
                const SizedBox(height: 20),
                if (lines.isNotEmpty)
                  HomeCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < lines.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: i == 0
                                  ? null
                                  : const Border(top: BorderSide(color: DojiColors.divider)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lines[i].$1.toUpperCase(), style: DojiType.label),
                                const SizedBox(height: 4),
                                Text(lines[i].$2, style: DojiType.body.copyWith(fontSize: 16, height: 1.4)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DojiButton(label: "i've read it", onPressed: onRead),
      ],
    );
  }
}

class _PledgeStep extends ConsumerWidget {
  const _PledgeStep({required this.onPledged});

  final VoidCallback onPledged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(homeSnapshotProvider).rules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(tag: 'rules pledge', title: 'your rules for today.'),
                const SizedBox(height: 20),
                HomeCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < rules.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: i == 0 ? null : const Border(top: BorderSide(color: DojiColors.divider)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}',
                                style: DojiType.config.copyWith(color: DojiColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  rules[i],
                                  style: DojiType.config.copyWith(color: DojiColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        HoldToPledgeButton(
          semanticLabel: "hold to pledge today's rules",
          onPledged: () {
            announce(context, 'pledged');
            Timer(const Duration(milliseconds: 300), () {
              if (context.mounted) onPledged();
            });
          },
        ),
      ],
    );
  }
}

class _BriefStep extends ConsumerWidget {
  const _BriefStep({required this.onReady});

  final VoidCallback onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(homeSnapshotProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(tag: 'today', title: 'one line for today.'),
                const SizedBox(height: 20),
                GlassSurface(
                  radius: DojiRadius.sheet,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snap.instruments.take(2).map(instrumentLabel).join(' · '), style: DojiType.hint),
                      const SizedBox(height: 12),
                      // TODO(next-slice): the day's line from the ai-brief function.
                      Text.rich(
                        TextSpan(
                          style: DojiType.body.copyWith(fontSize: 19),
                          children: [
                            const TextSpan(text: 'your session opens at '),
                            TextSpan(text: '[08:00]', style: DojiType.data.copyWith(fontSize: 17)),
                            const TextSpan(text: '. your setup needs a retest of '),
                            TextSpan(text: '[level]', style: DojiType.data.copyWith(fontSize: 17)),
                            const TextSpan(text: " first, so there's nothing to do until then."),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: DojiColors.separator)),
                        ),
                        child: Text(
                          'measured against your strategy · not financial advice',
                          style: DojiType.hint.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DojiButton(label: "i'm ready", onPressed: onReady),
      ],
    );
  }
}

class _DoneStep extends ConsumerWidget {
  const _DoneStep({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(homeControllerProvider.select((s) => s.mood));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                const GridCell(size: 36, state: GridCellState.l2, animateIn: true),
                const SizedBox(height: 20),
                TerminalLine(
                  'the open: complete.',
                  tone: TerminalTone.primary,
                  cursor: true,
                  style: DojiType.question.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  'rules pledged. mood saved: ${mood ?? '—'}. close your day tonight to fill the square.',
                  style: DojiType.callout.copyWith(fontSize: 17),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DojiButton(label: 'go home', variant: DojiButtonVariant.neutral, onPressed: onHome),
      ],
    );
  }
}

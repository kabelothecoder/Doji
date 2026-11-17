import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/platform/reminders.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/market_pause.dart';

enum PanicStep { breathe, ground, pause, talk, support, later }

const kSadagNumber = '0800 567 567';
const _pauseReminderId = 0x50414e31; // 'PAN1'
const _checkInReminderId = 0x50414e32; // 'PAN2'

/// "i blew my account" (design: Doji Panic Phone, Core Tabs › 08): breathe,
/// ground, pause, talk, support, later. A full-screen cover; close or done
/// leaves it.
class PanicScreen extends ConsumerStatefulWidget {
  const PanicScreen({super.key});

  @override
  ConsumerState<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends ConsumerState<PanicScreen> {
  var _step = PanicStep.breathe;
  final _grounds = [false, false];
  var _remind = true;
  var _callFailed = false;

  static const _groundLines = ['put both feet on the floor. notice them.', 'name three things you can see.'];

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.home);

  Future<void> _next() async {
    if (_step == PanicStep.pause) await _schedulePauseEnd();
    if (_step == PanicStep.later) return _leave();
    setState(() => _step = PanicStep.values[_step.index + 1]);
    if (_step == PanicStep.later) unawaited(_scheduleCheckIn());
  }

  Future<void> _schedulePauseEnd() async {
    final until = ref.read(marketPauseProvider);
    if (until == null || !_remind) return;
    await ref
        .read(remindersProvider)
        .schedule(
          id: _pauseReminderId,
          at: until,
          title: 'doji',
          body: 'your 24-hour pause is over. take it slow.',
        );
  }

  Future<void> _scheduleCheckIn() async {
    final now = clock.now();
    await ref
        .read(remindersProvider)
        .schedule(
          id: _checkInReminderId,
          at: DateTime(now.year, now.month, now.day + 1, 9),
          title: 'doji',
          body: 'how are you today? one line in your journal is enough.',
        );
  }

  Future<void> _callSadag() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: kSadagNumber.replaceAll(' ', '')));
    } catch (_) {}
    if (!ok && mounted) setState(() => _callFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DojiMotion.reduced(context);
    final i = _step.index;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    DojiIconButton(icon: Icons.close, semanticLabel: 'leave', onPressed: _leave),
                    Expanded(
                      child: Semantics(
                        label: 'step ${i + 1} of 6',
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var k = 0; k < 6; k++)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: k == i
                                        ? DojiColors.textPrimary
                                        : k < i
                                        ? const Color(0xFF6E7279)
                                        : DojiColors.separator,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: _step == PanicStep.later
                          ? null
                          : DojiButton(
                              label: i == 0 ? 'skip' : 'next',
                              variant: DojiButtonVariant.text,
                              size: DojiButtonSize.small,
                              onPressed: _next,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduced ? 200 : 900),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(child: _body(reduced)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(bool reduced) => switch (_step) {
    PanicStep.breathe => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TerminalLine('breathe with me.'),
        const SizedBox(height: 40),
        BreathingOrb(reduceMotion: reduced),
      ],
    ),
    PanicStep.ground => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("you're more than this account.", style: _h1),
        const SizedBox(height: 32),
        for (var k = 0; k < 2; k++) ...[
          if (k > 0) const SizedBox(height: 12),
          _GroundRow(
            text: _groundLines[k],
            done: _grounds[k],
            onTap: () => setState(() => _grounds[k] = !_grounds[k]),
          ),
        ],
      ],
    ),
    PanicStep.pause => _pauseBody(),
    PanicStep.talk => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DojiColors.dojiGreen.withValues(alpha: .08),
              border: Border.all(color: DojiColors.dojiGreen.withValues(alpha: .3)),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DojiColors.dojiGreen.withValues(alpha: .9),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('talk it through?', style: _h1, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Text(
          'the coach, at your pace. no market talk.',
          style: DojiType.callout.copyWith(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    PanicStep.support => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "if you're not okay, talk to someone now: SADAG $kSadagNumber (free, 24/7)",
          style: DojiType.headline.copyWith(fontSize: 24, fontWeight: FontWeight.w500, height: 1.3),
        ),
        const SizedBox(height: 20),
        DojiButton(
          label: 'call SADAG',
          icon: const Icon(Icons.call, size: 22),
          variant: DojiButtonVariant.neutral,
          size: DojiButtonSize.large,
          onPressed: _callSadag,
        ),
        if (_callFailed) ...[
          const SizedBox(height: 12),
          const TerminalLine("this device can't call. dial $kSadagNumber from your phone."),
        ],
      ],
    ),
    PanicStep.later => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TerminalLine("i'll check in tomorrow."),
        const SizedBox(height: 28),
        GlassSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'doji',
                    style: DojiType.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DojiColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text('tomorrow 09:00', style: DojiType.callout.copyWith(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'how are you today? one line in your journal is enough.',
                style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('you did enough for today.', style: DojiType.callout.copyWith(fontSize: 16)),
      ],
    ),
  };

  Widget _pauseBody() {
    final until = ref.watch(marketPauseProvider);
    final paused = until != null;
    final ends = until == null ? null : TimeOfDay.fromDateTime(until.toLocal()).format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("let's pause.", style: _h1),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: DojiColors.elevated1.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(DojiRadius.sheet),
            border: Border.all(color: DojiColors.separator),
          ),
          child: Column(
            children: [
              _SwitchRow(
                label: "pause doji's market views for 24 hours",
                value: paused,
                onChanged: (on) => unawaited(
                  on
                      ? ref.read(marketPauseProvider.notifier).start()
                      : ref.read(marketPauseProvider.notifier).stop(),
                ),
              ),
              const Divider(height: 1, color: DojiColors.elevated2),
              Opacity(
                opacity: paused ? 1 : .45,
                child: _SwitchRow(
                  label: 'remind me when it ends',
                  sub: ends == null ? null : 'tomorrow · $ends',
                  value: paused && _remind,
                  onChanged: paused ? (on) => setState(() => _remind = on) : null,
                ),
              ),
            ],
          ),
        ),
        // TODO(backend): "when Guard is connected, doji can lock trading too." Guard does not exist yet.
      ],
    );
  }

  List<Widget> _footer() => switch (_step) {
    PanicStep.breathe => [_outline("i'm a little calmer")],
    PanicStep.ground || PanicStep.pause || PanicStep.support => [_outline('continue')],
    PanicStep.talk => [
      DojiButton(
        label: 'talk to the coach',
        size: DojiButtonSize.large,
        onPressed: () => unawaited(context.push(Routes.coach)),
      ),
      DojiButton(
        label: 'not right now',
        variant: DojiButtonVariant.text,
        size: DojiButtonSize.small,
        onPressed: _next,
      ),
    ],
    PanicStep.later => [
      DojiButton(
        label: 'done',
        variant: DojiButtonVariant.neutral,
        size: DojiButtonSize.large,
        onPressed: _leave,
      ),
    ],
  };

  Widget _outline(String label) =>
      DojiButton(label: label, variant: DojiButtonVariant.outline, onPressed: _next);

  static final _h1 = DojiType.largeTitle.copyWith(fontWeight: FontWeight.w500, height: 1.15);
}

class _GroundRow extends StatelessWidget {
  const _GroundRow({required this.text, required this.done, required this.onTap});

  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = done ? DojiColors.dojiGreen : DojiColors.separator;
    return Semantics(
      button: true,
      toggled: done,
      child: DojiPressable(
        onPressed: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: DojiColors.elevated1.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(DojiRadius.sheet),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(child: Text(text, style: DojiType.body.copyWith(height: 1.4))),
              const SizedBox(width: 14),
              ExcludeSemantics(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? DojiColors.dojiGreen : Colors.transparent,
                    border: Border.all(color: border, width: 2),
                  ),
                  child: done ? const Icon(Icons.check, size: 16, color: DojiColors.bg) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.sub});

  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DojiType.body.copyWith(fontSize: 16, height: 1.4)),
                if (sub != null) Text(sub!, style: DojiType.label.copyWith(color: DojiColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: DojiColors.dojiGreen),
        ],
      ),
    ),
  );
}

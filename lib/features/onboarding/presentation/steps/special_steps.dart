import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/profile_doji.dart';
import 'step_input.dart';

/// Handoff step 0: "Lines type at 28ms/char, 400ms pause between."
class BootStepView extends StatefulWidget {
  const BootStepView({super.key, required this.wide});

  final bool wide;

  static const lines = ['initializing doji…', 'no holy grail found.', 'building yours.'];

  @override
  State<BootStepView> createState() => _BootStepViewState();
}

class _BootStepViewState extends State<BootStepView> {
  int _line = 0;
  bool _hello = false;
  final _done = <int>{};
  Timer? _pause;

  /// Lines can finish out of order (tap-to-skip, reduce motion), so track
  /// completion per line and move to the first one still typing.
  void _lineDone(int i) {
    _done.add(i);
    _pause?.cancel();
    final reduced = DojiMotion.reduced(context);
    _pause = Timer(reduced ? Duration.zero : DojiMotion.linePause, () {
      if (!mounted) return;
      final n = BootStepView.lines.length;
      final next = List.generate(n, (k) => k).where((k) => !_done.contains(k)).firstOrNull;
      setState(() {
        if (next == null) {
          _line = n - 1;
          _hello = true;
        } else {
          _line = next;
        }
      });
    });
  }

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = BootStepView.lines.length - 1;
    return FillScroll(
      alignment: MainAxisAlignment.spaceBetween,
      reverse: false,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: widget.wide ? 16 : 40),
            for (var i = 0; i < BootStepView.lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TypingText(
                  BootStepView.lines[i],
                  start: i <= _line,
                  style: DojiType.terminal.copyWith(
                    color: i == last ? DojiColors.textPrimary : DojiColors.textSecondary,
                  ),
                  showCursor: i == _line,
                  cursorAfterDone: i == last,
                  liveRegion: i == 0,
                  onDone: () => _lineDone(i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        AnimatedOpacity(
          opacity: _hello ? 1 : 0,
          duration: DojiMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text("hey. i'm doji.", style: DojiType.hero)),
              const SizedBox(height: 12),
              Text("let's set you up — about 3 minutes.", style: DojiType.heroSub),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

/// Handoff step 1. "Second line in secondary grey so the eye lands on
/// 'balance'." Asset #1 (Higgsfield) was never generated: grain only.
class ManifestoStepView extends StatelessWidget {
  const ManifestoStepView({super.key});

  @override
  Widget build(BuildContext context) {
    return FillScroll(
      alignment: MainAxisAlignment.center,
      reverse: false,
      children: [
        Text('> MANIFESTO', style: DojiType.label.copyWith(color: DojiColors.dojiGreen, letterSpacing: 0.96)),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          label: 'There is no holy grail. There is balance.',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: DojiType.manifesto,
                children: const [
                  TextSpan(text: 'There is no holy grail.\n'),
                  TextSpan(
                    text: 'There is balance.',
                    style: TextStyle(color: DojiColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Brief step 6: `> compiling profile.doji…`, the config prints line by line,
/// then collapses into a profile card — rank M1 · Impulsive, "everyone starts
/// here". Not in the handoff; built from design-system parts.
class CompileStepView extends StatefulWidget {
  const CompileStepView({super.key, required this.lines, required this.profile, required this.onCompiled});

  final List<ConfigLineData> lines;
  final ProfileDoji profile;
  final VoidCallback onCompiled;

  @override
  State<CompileStepView> createState() => _CompileStepViewState();
}

class _CompileStepViewState extends State<CompileStepView> {
  int _printed = 0;
  bool _collapsed = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DojiMotion.reduced(context) && !_collapsed) {
      _printed = widget.lines.length;
      _collapsed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCompiled());
    }
  }

  void _print() {
    _timer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) return t.cancel();
      if (_printed < widget.lines.length) {
        setState(() => _printed++);
        return;
      }
      t.cancel();
      _timer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _collapsed = true);
        widget.onCompiled();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _valueColor(ConfigValueTone t) => switch (t) {
    ConfigValueTone.symbol => DojiColors.dojiGreen,
    ConfigValueTone.muted => DojiColors.textSecondary,
    ConfigValueTone.literal => DojiColors.textPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final rank = widget.profile.rank;
    return FillScroll(
      alignment: MainAxisAlignment.start,
      reverse: false,
      children: [
        const SizedBox(height: 8),
        TypingText(
          'compiling profile.doji…',
          style: DojiType.terminal,
          cursorAfterDone: false,
          onDone: () {
            if (!_collapsed && _timer == null) _print();
          },
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: child),
          ),
          child: _collapsed
              ? SizedBox(
                  key: const ValueKey('card'),
                  width: double.infinity, // AnimatedSwitcher's Stack loosens width
                  child: _ProfileCard(profile: widget.profile, lines: widget.lines.length, rank: rank),
                )
              : Column(
                  key: const ValueKey('lines'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final l in widget.lines.take(_printed))
                      Text.rich(
                        TextSpan(
                          style: DojiType.config.copyWith(height: 1.7),
                          children: [
                            TextSpan(
                              text: '${l.number.toString().padLeft(2)}  ${l.keyName}: ',
                              style: const TextStyle(color: DojiColors.textSecondary),
                            ),
                            TextSpan(
                              text: l.value,
                              style: TextStyle(color: _valueColor(l.tone)),
                            ),
                            TextSpan(
                              text: l.comment,
                              style: const TextStyle(color: DojiColors.textSecondary),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.lines, required this.rank});

  final ProfileDoji profile;
  final int lines;
  final String rank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'profile compiled. rank $rank, ${dojiRanks[rank]}. everyone starts here.',
      child: ExcludeSemantics(
        child: GlassSurface(
          radius: DojiRadius.sheet,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('> PROFILE.DOJI · COMPILED', style: DojiType.label.copyWith(color: DojiColors.dojiGreen)),
              const SizedBox(height: 14),
              Text(profile.name ?? 'you', style: DojiType.title),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: RankPill(code: rank, name: dojiRanks[rank] ?? ''),
              ),
              const SizedBox(height: 12),
              Text('everyone starts here.', style: DojiType.callout),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DojiColors.separator)),
                ),
                child: Text('$lines lines · rules v1 · stored on this device', style: DojiType.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Handoff step 6 (ASSUMED there): hold to pledge; on completion the first
/// Grid square lights with dojiFill.
class PledgeStepView extends StatelessWidget {
  const PledgeStepView({super.key, required this.pledged, required this.onPledged, required this.wide});

  final bool pledged;
  final VoidCallback onPledged;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The faint green wick behind the pledge (handoff: 1px at 55%, from
        // 18% to 66% of the frame), centred on the hold ring's column.
        const Positioned.fill(
          child: IgnorePointer(
            child: FractionallySizedBox(
              alignment: Alignment(0, -0.28),
              heightFactor: 0.48,
              child: Center(
                child: SizedBox(
                  width: 1,
                  height: double.infinity,
                  child: ColoredBox(color: Color(0x8C2FD67B)),
                ),
              ),
            ),
          ),
        ),
        _content(),
      ],
    );
  }

  Widget _content() {
    return FillScroll(
      alignment: MainAxisAlignment.spaceBetween,
      reverse: false,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '> PLEDGE · RULES V1',
              style: DojiType.label.copyWith(color: DojiColors.dojiGreen, letterSpacing: 0.96),
            ),
            const SizedBox(height: 20),
            Semantics(header: true, child: Text('your plan,\nnot your feelings.', style: DojiType.pledge)),
          ],
        ),
        const SizedBox(height: 24),
        Column(
          children: [
            HoldToPledgeButton(pledged: pledged, onPledged: onPledged, autofocus: wide),
            const SizedBox(height: 24),
            _FirstWeek(lit: pledged),
            const SizedBox(height: 16),
          ],
        ),
      ],
    );
  }
}

/// This week's row of the Doji Grid: today lights up when the pledge lands.
class _FirstWeek extends StatelessWidget {
  const _FirstWeek({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: lit ? 1 : 0.35,
      duration: const Duration(milliseconds: 240),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                GridCell(
                  size: 16,
                  state: i == 0 && lit ? GridCellState.today : GridCellState.future,
                  animateIn: i == 0,
                  semanticLabel: i == 0
                      ? (lit ? 'today, first square lit' : 'today')
                      : 'day ${i + 1}, not yet',
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(lit ? 'GRID · DAY 1' : 'GRID', style: DojiType.hint), // doji voice
        ],
      ),
    );
  }
}

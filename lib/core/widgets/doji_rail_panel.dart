import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_button.dart';
import 'doji_pressable.dart';
import 'glass_surface.dart';
import 'key_hints.dart';
import 'rule_meter.dart';
import 'terminal_line.dart';

/// One row of the rail's rule meters.
typedef RailMeter = ({String label, num used, num limit, String unit});

/// Design system: `Doji Rail` (Doji Rail.dc.html): the desktop companion
/// panel that sits beside the chart: the instrument's strategy state, rule meters,
/// tilt, the next news and "log emotion". Expanded (360 × 640 in the design)
/// or mini (two mono rows).
///
/// TODO(next-slice): the design is an always-on-top OS window (pin icon).
/// For now the panel docks inside Home on wide screens; promote it to a
/// separate window with window_manager once the Windows shell needs it.
class DojiRailPanel extends StatefulWidget {
  const DojiRailPanel({
    super.key,
    required this.instrument,
    required this.strategyLine,
    required this.conditionsMet,
    required this.meters,
    required this.tiltLevel,
    required this.tiltWord,
    required this.nextNews,
    required this.newsCountdown,
    required this.onLogEmotion,
    this.onOpenBrief,
    this.onClose,
    this.logged,
    this.initiallyExpanded = true,
  });

  final String instrument;

  /// "london breakout · 5/5 · [2m] ago"
  final String strategyLine;
  final bool conditionsMet;
  final List<RailMeter> meters;

  /// 1–5 of five segments filled.
  final int tiltLevel;
  final String tiltWord;
  final String nextNews;
  final String newsCountdown;
  final VoidCallback onLogEmotion;
  final VoidCallback? onOpenBrief;
  final VoidCallback? onClose;

  /// "before the trade · 6/10": shown as a terminal line once something is logged.
  final String? logged;
  final bool initiallyExpanded;

  @override
  State<DojiRailPanel> createState() => _DojiRailPanelState();
}

class _DojiRailPanelState extends State<DojiRailPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'doji rail',
      child: GlassSurface(
        radius: 12,
        tint: DojiColors.elevated1,
        fillOpacity: 0.94,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_titleBar(), if (_expanded) _expandedBody() else _miniBody()],
        ),
      ),
    );
  }

  Widget _titleBar() => Container(
    height: 32,
    padding: const EdgeInsets.only(left: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: DojiColors.separator)),
    ),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(color: DojiColors.dojiGreen, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('doji rail', style: DojiType.hint),
        const Spacer(),
        const Tooltip(
          message: 'always on top',
          child: Icon(Icons.push_pin_rounded, size: 15, color: DojiColors.dojiGreen),
        ),
        _TitleButton(
          icon: _expanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
          label: _expanded ? 'collapse' : 'expand',
          width: 36,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
        if (widget.onClose != null)
          _TitleButton(icon: Icons.close_rounded, label: 'close rail', width: 40, onPressed: widget.onClose!),
      ],
    ),
  );

  Widget _expandedBody() {
    final met = widget.conditionsMet;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Strategy state: shape + word, never colour alone.
          Semantics(
            container: true,
            label: '${widget.instrument}, ${met ? 'conditions met' : 'waiting'}. ${widget.strategyLine}',
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: met ? DojiColors.greenTint.withValues(alpha: 0.5) : DojiColors.elevated1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: met ? DojiColors.dojiGreen.withValues(alpha: 0.45) : DojiColors.separator,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StateDot(filled: met),
                        const SizedBox(width: 8),
                        Text(widget.instrument, style: DojiType.data.copyWith(fontSize: 15)),
                        const Spacer(),
                        Text(
                          met ? 'conditions met' : 'waiting',
                          style: DojiType.hint.copyWith(
                            color: met ? DojiColors.dojiGreen : DojiColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.strategyLine, style: DojiType.hint),
                    if (widget.onOpenBrief != null) ...[
                      const SizedBox(height: 8),
                      DojiButton(
                        label: 'open brief',
                        variant: DojiButtonVariant.secondary,
                        size: DojiButtonSize.small,
                        expand: false,
                        onPressed: widget.onOpenBrief,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final m in widget.meters) ...[
            RuleMeter(label: m.label, used: m.used, limit: m.limit, unit: m.unit),
            const SizedBox(height: 14),
          ],
          _tilt(),
          const SizedBox(height: 14),
          _news(),
          if (widget.logged != null) ...[
            const SizedBox(height: 14),
            TerminalLine('logged: ${widget.logged}', tone: TerminalTone.primary, cursor: true),
          ],
          const SizedBox(height: 14),
          DojiButton(
            label: 'log emotion',
            variant: DojiButtonVariant.neutral,
            size: DojiButtonSize.regular,
            onPressed: widget.onLogEmotion,
          ),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerRight, child: KeyHints(['ctrl shift d'])),
        ],
      ),
    );
  }

  Widget _tilt() {
    final high = widget.tiltLevel >= 3;
    return Semantics(
      container: true,
      label: 'tilt, ${widget.tiltWord}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('tilt', style: DojiType.callout.copyWith(fontSize: 14))),
                Text(
                  widget.tiltWord,
                  style: DojiType.config.copyWith(
                    color: high ? DojiColors.tiltOrange : DojiColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < widget.tiltLevel
                            ? (high ? DojiColors.tiltOrange : DojiColors.textPrimary)
                            : DojiColors.separator,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text('from recent losses and emotion logs', style: DojiType.hint.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _news() => Semantics(
    container: true,
    label: 'next news ${widget.nextNews} in ${widget.newsCountdown}',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('next news', style: DojiType.callout.copyWith(fontSize: 12)),
                  Text(widget.nextNews, style: DojiType.config.copyWith(color: DojiColors.textPrimary)),
                ],
              ),
            ),
            // Price and time are neutral grey/white, never green or orange.
            Text(widget.newsCountdown, style: DojiType.data.copyWith(fontSize: 20)),
          ],
        ),
      ),
    ),
  );

  Widget _miniBody() {
    final u = widget.meters;
    final mono = DojiType.hint.copyWith(color: DojiColors.textPrimary);
    final trades = u.isEmpty ? null : u.first;
    final loss = u.length > 1 ? u[1] : null;
    String n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (trades != null) Text('${n(trades.used)}/${n(trades.limit)} ${trades.label}', style: mono),
              if (loss != null)
                Text('${n(loss.used)}${loss.unit}/${n(loss.limit)}${loss.unit}', style: DojiType.hint),
              Text('${widget.nextNews} ${widget.newsCountdown}', style: DojiType.hint),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StateDot(filled: widget.conditionsMet, size: 9),
              const SizedBox(width: 8),
              Text(widget.instrument, style: mono),
              const SizedBox(width: 8),
              Text(
                widget.conditionsMet ? 'conditions met' : 'waiting',
                style: DojiType.hint.copyWith(
                  color: widget.conditionsMet ? DojiColors.dojiGreen : DojiColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text('log ↵', style: DojiType.hint),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filled = conditions met, ring = waiting (the design's shape + word rule).
class _StateDot extends StatelessWidget {
  const _StateDot({required this.filled, this.size = 10});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? DojiColors.dojiGreen : Colors.transparent,
        border: filled ? null : Border.all(color: DojiColors.textSecondary, width: 2),
        boxShadow: filled
            ? [BoxShadow(color: DojiColors.dojiGreen.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
    ),
  );
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({required this.icon, required this.label, required this.width, required this.onPressed});

  final IconData icon;
  final String label;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: DojiPressable(
      onPressed: onPressed,
      semanticLabel: label,
      showPressedOverlay: false,
      child: SizedBox(
        width: width,
        height: 32,
        child: Icon(icon, size: 16, color: DojiColors.textSecondary),
      ),
    ),
  );
}

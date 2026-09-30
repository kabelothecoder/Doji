import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

enum GridCellState { l0, l1, l2, l3, l4, today, future }

/// Design system: `GridCell` inside `DojiGrid(weeks: 52)`.
///
/// Levels L0–L4 use DojiColors.grid. "today" is L2 with a 1.5px white ring;
/// "future" is an empty cell with a 1px separator inset. Fill-in animation is
/// dojiFill: 360ms cubic-bezier(.2,.9,.3,1.2), opacity 0→1, scale .3→1.
///
/// Colour is never the only signal: every cell has a spoken label.
class GridCell extends StatefulWidget {
  const GridCell({
    super.key,
    required this.state,
    this.size = 11,
    this.animateIn = false,
    this.delay = Duration.zero,
    this.semanticLabel,
  });

  final GridCellState state;
  final double size;

  /// Play dojiFill when this cell first appears (or when [state] lights up).
  final bool animateIn;
  final Duration delay;
  final String? semanticLabel;

  static String describe(GridCellState s) => switch (s) {
    GridCellState.l0 => 'no points',
    GridCellState.l1 => 'one point',
    GridCellState.l2 => 'two points',
    GridCellState.l3 => 'three points',
    GridCellState.l4 => 'full discipline',
    GridCellState.today => 'today',
    GridCellState.future => 'not yet',
  };

  @override
  State<GridCell> createState() => _GridCellState();
}

class _GridCellState extends State<GridCell> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: DojiMotion.gridFill,
    value: widget.animateIn ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    // Reduce motion is read from MediaQuery, which isn't available yet.
    if (widget.animateIn) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(GridCell old) {
    super.didUpdateWidget(old);
    if (widget.animateIn && old.state != widget.state) {
      _fill.value = 0;
      _play();
    }
  }

  Future<void> _play() async {
    if (widget.delay > Duration.zero) await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    if (DojiMotion.reduced(context)) {
      _fill.value = 1;
    } else {
      await _fill.forward();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final radius = BorderRadius.circular(widget.size >= 16 ? 3 : 2);
    final Color fill = switch (s) {
      GridCellState.l0 => DojiColors.grid[0],
      GridCellState.l1 => DojiColors.grid[1],
      GridCellState.l2 || GridCellState.today => DojiColors.grid[2],
      GridCellState.l3 => DojiColors.grid[3],
      GridCellState.l4 => DojiColors.grid[4],
      GridCellState.future => Colors.transparent,
    };
    final Border? border = switch (s) {
      GridCellState.today => Border.all(color: DojiColors.textPrimary, width: 1.5),
      GridCellState.future => Border.all(color: DojiColors.separator),
      _ => null,
    };
    final cell = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: fill, borderRadius: radius, border: border),
    );
    return Semantics(
      label: widget.semanticLabel ?? GridCell.describe(s),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _fill,
          builder: (context, child) {
            final t = DojiMotion.gridFillCurve.transform(_fill.value);
            return Opacity(
              opacity: _fill.value.clamp(0, 1),
              child: Transform.scale(scale: 0.3 + 0.7 * t, child: child),
            );
          },
          child: cell,
        ),
      ),
    );
  }
}

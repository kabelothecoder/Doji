import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Shared interaction shell for every tappable doji component.
///
/// Not a design-system component itself; it implements the system-wide rules:
/// doji-green focus ring (2px, 3px outset), press = scale .98 + 8% white
/// overlay, keyboard activation, and a single semantics node.
class DojiPressable extends StatefulWidget {
  const DojiPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel,
    this.semanticHint,
    this.selected,
    this.checked,
    this.inMutuallyExclusiveGroup = false,
    this.activateOnEnter = true,
    this.focusNode,
    this.autofocus = false,
    this.pressedScale = 0.98,
    this.showPressedOverlay = true,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;

  /// When set, replaces the child's semantics with this label.
  final String? semanticLabel;
  final String? semanticHint;
  final bool? selected;
  final bool? checked;
  final bool inMutuallyExclusiveGroup;

  /// Buttons activate on Enter and Space. Choice chips set this to false so
  /// Enter bubbles up to the screen's "continue" shortcut, like a native form.
  final bool activateOnEnter;
  final FocusNode? focusNode;
  final bool autofocus;
  final double pressedScale;
  final bool showPressedOverlay;
  final MouseCursor mouseCursor;

  @override
  State<DojiPressable> createState() => _DojiPressableState();
}

class _DojiPressableState extends State<DojiPressable> {
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DojiMotion.reduced(context);
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
      if (widget.activateOnEnter) ...{
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
    };

    Widget body = widget.child;
    if (widget.showPressedOverlay) {
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: _pressed ? const Color(0x14FFFFFF) : Colors.transparent,
        ),
        child: body,
      );
    }

    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup ? true : null,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? widget.mouseCursor : SystemMouseCursors.basic,
        shortcuts: shortcuts,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: CustomPaint(
            foregroundPainter: _FocusRingPainter(visible: _focused, radius: widget.borderRadius),
            child: AnimatedScale(
              scale: _pressed && !reduced ? widget.pressedScale : 1,
              duration: const Duration(milliseconds: 90),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.visible, required this.radius});

  final bool visible;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final rrect = radius.toRRect(Offset.zero & size).inflate(3);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DojiColors.dojiGreen,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) => old.visible != visible || old.radius != radius;
}

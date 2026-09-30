import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_pressable.dart';

enum DojiChoiceStyle {
  /// Full-width answer tile for single choice (56pt, check on the right).
  tile,

  /// Compact chip for multi choice (48pt, wraps).
  chip,
}

/// Design system: `DojiChip` (chips take input) as used by `DojiChoiceGrid`
/// and the multi-choice `FilterChip`s in the onboarding handoff.
///
/// Selected = white fill with a check glyph, "not only colour".
/// Radius follows the handoff per platform: 16 on iOS/Windows, 10 on Android.
class DojiChoiceChip extends StatelessWidget {
  const DojiChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.style = DojiChoiceStyle.tile,
    this.mono = false,
    this.dashed = false,
    this.sub,
    this.keyHint,
    this.center = false,
    this.minHeight,
    this.exclusive = false,
    this.focusNode,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final DojiChoiceStyle style;

  /// Symbols and numbers render in Geist Mono.
  final bool mono;

  /// "+ custom": dashed hairline, secondary label.
  final bool dashed;

  /// Second line (ritual chips: "30m before").
  final String? sub;

  /// Keyboard hint shown on desktop ("1"–"9").
  final String? keyHint;
  final bool center;
  final double? minHeight;

  /// Part of a single-choice (radio) group.
  final bool exclusive;
  final FocusNode? focusNode;
  final TextStyle? textStyle;

  static double radiusFor(TargetPlatform p) =>
      p == TargetPlatform.android ? DojiRadius.chip : DojiRadius.card;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(radiusFor(Theme.of(context).platform));
    final fg = selected
        ? DojiColors.bg
        : dashed
        ? DojiColors.textSecondary
        : DojiColors.textPrimary;
    final bg = selected ? DojiColors.textPrimary : DojiColors.elevated1;
    final base =
        textStyle ??
        (mono
            ? DojiType.chipMono
            : style == DojiChoiceStyle.tile
            ? DojiType.choice
            : DojiType.chip);
    final labelStyle = base.copyWith(color: fg);
    final isTile = style == DojiChoiceStyle.tile;
    final showKey = keyHint != null && PlatformInfo.isDesktop;

    final check = Icon(Icons.check_rounded, size: 20, color: fg);
    final Widget labelWidget = sub == null
        ? Text(label, style: labelStyle, textAlign: center ? TextAlign.center : TextAlign.start)
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: labelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(
                sub!,
                style: DojiType.hint.copyWith(color: fg.withValues(alpha: 0.8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          );

    Widget content;
    if (center) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected && sub == null) ...[check, const SizedBox(width: 6)],
          Flexible(child: labelWidget),
          if (showKey) ...[const SizedBox(width: 8), _KeyHint(keyHint!, color: fg)],
        ],
      );
    } else if (isTile) {
      content = Row(
        children: [
          Expanded(child: labelWidget),
          const SizedBox(width: 8),
          Opacity(opacity: selected ? 1 : 0, child: check),
          if (showKey) ...[const SizedBox(width: 8), _KeyHint(keyHint!, color: fg)],
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[Icon(Icons.check_rounded, size: 18, color: fg), const SizedBox(width: 6)],
          Flexible(child: labelWidget),
          if (showKey) ...[const SizedBox(width: 8), _KeyHint(keyHint!, color: fg)],
        ],
      );
    }

    final box = Container(
      constraints: BoxConstraints(minHeight: minHeight ?? (isTile ? 56 : 48), minWidth: 48),
      // Centred chips (risk %, ritual times) sit four or three to a row.
      padding: EdgeInsets.symmetric(horizontal: center ? 8 : (isTile ? 18 : 16), vertical: 8),
      alignment: isTile && !center ? Alignment.centerLeft : Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: dashed ? null : Border.all(color: selected ? DojiColors.textPrimary : DojiColors.separator),
      ),
      child: content,
    );

    return DojiPressable(
      onPressed: onTap,
      borderRadius: radius,
      selected: exclusive ? null : selected,
      checked: selected,
      inMutuallyExclusiveGroup: exclusive,
      activateOnEnter: false,
      focusNode: focusNode,
      semanticLabel: sub == null ? label : '$label, $sub',
      child: dashed ? CustomPaint(painter: _DashedBorder(radius), child: box) : box,
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.keyLabel, {required this.color});

  final String keyLabel;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(keyLabel, style: DojiType.hint.copyWith(color: color.withValues(alpha: 0.7))),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(radius.toRRect(Offset.zero & size).deflate(0.5));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DojiColors.separator;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.radius != radius;
}

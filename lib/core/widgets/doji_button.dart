import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_pressable.dart';

enum DojiButtonVariant {
  /// doji-green fill, bg-coloured label. "continue", "let's go".
  primary,

  /// elevated-2 fill, separator hairline.
  secondary,

  /// Transparent, secondary grey label. "skip for now", "not now".
  text,

  /// Transparent, doji-green label (`.ghost`).
  ghost,

  /// Tilt-orange fill (`.caution`).
  caution,
}

enum DojiButtonSize {
  /// 56 — onboarding and auth footers.
  large,

  /// 52 — design system default.
  regular,

  /// 44 — secondary actions and text buttons.
  small,
}

/// Design system: `DojiButton` (52 / 44, pill) with `.ghost`, `.caution`,
/// disabled and `.icon` variants. Heights are minimums: at large text sizes
/// the button grows taller instead of clipping its label.
class DojiButton extends StatelessWidget {
  const DojiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DojiButtonVariant.primary,
    this.size = DojiButtonSize.large,
    this.icon,
    this.expand = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final DojiButtonVariant variant;
  final DojiButtonSize size;
  final Widget? icon;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  /// 44pt minimum on iOS/desktop, 48dp on Android.
  double _height(BuildContext context) => switch (size) {
    DojiButtonSize.large => 56,
    DojiButtonSize.regular => 52,
    DojiButtonSize.small => DojiTokens.of(context).minTarget,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      _ when !enabled && variant != DojiButtonVariant.text => (
        DojiColors.elevated2,
        DojiColors.textTertiary,
        null,
      ),
      DojiButtonVariant.primary => (DojiColors.dojiGreen, DojiColors.bg, null),
      DojiButtonVariant.secondary => (DojiColors.elevated2, DojiColors.textPrimary, DojiColors.separator),
      DojiButtonVariant.text => (
        Colors.transparent,
        enabled ? DojiColors.textSecondary : DojiColors.textTertiary,
        null,
      ),
      DojiButtonVariant.ghost => (Colors.transparent, DojiColors.dojiGreen, null),
      DojiButtonVariant.caution => (DojiColors.tiltOrange, DojiColors.bg, null),
    };
    final isQuiet = variant == DojiButtonVariant.text || variant == DojiButtonVariant.ghost;
    final style = (isQuiet || size == DojiButtonSize.small ? DojiType.callout : DojiType.button).copyWith(
      color: fg,
      fontWeight: variant == DojiButtonVariant.secondary || isQuiet ? FontWeight.w500 : FontWeight.w600,
    );
    final radius = BorderRadius.circular(DojiRadius.pill);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(color: fg, size: 22),
            child: icon!,
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(label, style: style, textAlign: TextAlign.center),
        ),
      ],
    );

    return DojiPressable(
      onPressed: onPressed,
      borderRadius: radius,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _height(context), minWidth: _height(context)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: border == null ? null : Border.all(color: border),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isQuiet ? 12 : 28, vertical: 10),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// Design system: `DojiButton.icon` — 44 circle, always carries a semantic label.
class DojiIconButton extends StatelessWidget {
  const DojiIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
    this.size,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Green fill (the mic, the active play button).
  final bool filled;

  /// Defaults to the platform touch target (44pt / 48dp).
  final double? size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (filled ? DojiColors.dojiGreen : DojiColors.elevated2);
    final fg = foreground ?? (filled ? DojiColors.bg : DojiColors.textPrimary);
    final size = this.size ?? DojiTokens.of(context).minTarget;
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: DojiPressable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: DojiColors.separator),
          ),
          child: Icon(icon, size: 22, color: fg),
        ),
      ),
    );
  }
}

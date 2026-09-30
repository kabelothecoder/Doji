import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../haptics/doji_haptics.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_choice_chip.dart';
import 'doji_pressable.dart';

/// Design system: `DojiStepper` — "Row › IconButton, AnimatedSwitcher(value),
/// IconButton". 44pt buttons; TalkBack/VoiceOver read it as an adjustable
/// value ("3 trades, max per day").
class DojiStepper extends StatelessWidget {
  const DojiStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.format,
    this.semanticUnit = '',
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String Function(double v)? format;

  /// Spoken after the value, e.g. "trades" or "percent".
  final String semanticUnit;

  String _fmt(double v) => format?.call(v) ?? v.toStringAsFixed(0);

  double _clamp(double v) => (v.clamp(min, max) * 1000).roundToDouble() / 1000;

  void _dec() {
    if (value > min) {
      unawaited(const DojiHaptics().tick());
      onChanged(_clamp(value - step));
    }
  }

  void _inc() {
    if (value < max) {
      unawaited(const DojiHaptics().tick());
      onChanged(_clamp(value + step));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(DojiChoiceChip.radiusFor(Theme.of(context).platform));
    final spoken = '${_fmt(value)} $semanticUnit'.trim();
    return Semantics(
      container: true,
      label: label,
      value: spoken,
      increasedValue: value < max ? '${_fmt(_clamp(value + step))} $semanticUnit'.trim() : null,
      decreasedValue: value > min ? '${_fmt(_clamp(value - step))} $semanticUnit'.trim() : null,
      onIncrease: value < max ? _inc : null,
      onDecrease: value > min ? _dec : null,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (e.logicalKey == LogicalKeyboardKey.arrowUp || e.logicalKey == LogicalKeyboardKey.arrowRight) {
            _inc();
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowDown || e.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _dec();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(child: Text(label, style: DojiType.body)),
              ),
              _StepButton(
                icon: Icons.remove_rounded,
                label: 'Decrease $label',
                radius: r,
                onPressed: value > min ? _dec : null,
              ),
              SizedBox(
                width: 60,
                child: ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: DojiMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 160),
                    child: Text(
                      _fmt(value),
                      key: ValueKey(value),
                      textAlign: TextAlign.center,
                      style: DojiType.data.copyWith(fontSize: 20),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                label: 'Increase $label',
                radius: r,
                onPressed: value < max ? _inc : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.radius, required this.onPressed});

  final IconData icon;
  final String label;
  final BorderRadius radius;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final size = DojiTokens.of(context).minTarget;
    return DojiPressable(
      onPressed: onPressed,
      semanticLabel: label,
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: radius),
        child: Icon(
          icon,
          size: 20,
          color: onPressed == null ? DojiColors.textTertiary : DojiColors.textPrimary,
        ),
      ),
    );
  }
}

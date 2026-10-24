import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/doji_haptics.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Handoff 1c `PushToTalkButton(onLongPress)`: the 64-tall pill between save
/// and end. White, green while the mic is open.
///
/// Hold it and release to send, or tap once to open the mic and tap again to
/// send. Screen readers and the keyboard (Space, Enter) get the tap version.
/// A haptic tick on press and on release.
class PushToTalkButton extends ConsumerStatefulWidget {
  const PushToTalkButton({
    super.key,
    required this.state,
    required this.tapToSend,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
  });

  final VoiceOrbState state;

  /// The mic was opened with a tap, so the next tap sends.
  final bool tapToSend;
  final bool enabled;

  /// [tap]: a screen reader or keyboard activation, not a pointer.
  final void Function({bool tap}) onPress;
  final void Function({required bool held}) onRelease;

  /// Down at least this long counts as a hold: release sends.
  static const holdThreshold = Duration(milliseconds: 350);

  String get label => switch (state) {
    VoiceOrbState.listening => tapToSend ? 'tap to send' : 'release to send',
    VoiceOrbState.speaking => 'hold to interrupt',
    VoiceOrbState.idle => 'hold to talk',
  };

  @override
  ConsumerState<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends ConsumerState<PushToTalkButton> {
  DateTime? _downAt;
  bool _focused = false;

  void _down() {
    if (!widget.enabled) return;
    _downAt = clock.now();
    ref.read(hapticsProvider).tick();
    widget.onPress();
  }

  void _up() {
    final down = _downAt;
    if (down == null) return;
    _downAt = null;
    ref.read(hapticsProvider).tick();
    widget.onRelease(held: clock.now().difference(down) >= PushToTalkButton.holdThreshold);
  }

  void _activate() {
    if (!widget.enabled) return;
    ref.read(hapticsProvider).tick();
    widget.onPress(tap: true);
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.state == VoiceOrbState.listening;
    final reduced = DojiMotion.reduced(context);
    final pill = AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: !widget.enabled
            ? DojiColors.elevated2
            : listening
            ? DojiColors.dojiGreen
            : DojiColors.textPrimary,
        borderRadius: BorderRadius.circular(DojiRadius.pill),
        border: _focused ? Border.all(color: DojiColors.dojiGreen, width: 2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_rounded, size: 24, color: widget.enabled ? DojiColors.bg : DojiColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: DojiType.button.copyWith(
                color: widget.enabled ? DojiColors.bg : DojiColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      hint: listening ? null : 'or tap to start, then tap to send',
      onTap: widget.enabled ? _activate : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        mouseCursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: pill,
        ),
      ),
    );
  }
}

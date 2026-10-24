import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/biometric_kind.dart';
import 'app_lock_controller.dart';

/// Design system: `BiometricLockScreen` (auth component spec, A8b).
///
/// Wraps the whole router. "Content is blurred behind glass, also in the app
/// switcher. Face ID triggers automatically on appear; the button retries."
/// While locked, nothing underneath can be tapped, focused or read aloud.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _life;
  bool _autoTried = false;

  AppLockController get _lock => ref.read(appLockControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Phones blur as soon as the app switcher opens (inactive). On Windows,
    // losing focus to another window is normal; only minimising counts.
    _life = AppLifecycleListener(
      onInactive: PlatformInfo.isDesktop ? null : _lock.onBackground,
      onHide: _lock.onBackground,
      onResume: _lock.onForeground,
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _autoUnlock(AppLockState s) {
    if (!s.locked) {
      _autoTried = false;
      return;
    }
    if (_autoTried || s.authenticating || !s.kindLoaded || s.obscured) return;
    _autoTried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_lock.unlock());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appLockControllerProvider);
    _autoUnlock(s);
    final covered = s.locked || s.obscured;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        ExcludeSemantics(
          excluding: covered,
          child: ExcludeFocus(
            excluding: s.locked,
            child: IgnorePointer(ignoring: s.locked, child: widget.child),
          ),
        ),
        if (covered) Positioned.fill(child: _LockScreen(state: s)),
      ],
    );
  }
}

class _LockScreen extends ConsumerWidget {
  const _LockScreen({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = state.kind;
    final name = kind?.name ?? 'passcode';
    final fallback = switch (kind) {
      null || BiometricKind.screenLock || BiometricKind.windowsHello => null,
      _ when PlatformInfo.isIOS => 'use passcode',
      _ => 'use PIN, pattern or password',
    };
    final lock = ref.read(appLockControllerProvider.notifier);
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;

    return Material(
      type: MaterialType.transparency,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: ColoredBox(
            color: DojiColors.elevated1.withValues(alpha: state.locked ? 0.55 : 0.85),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const DojiAppIcon(size: 72),
                                  if (state.locked) ...[
                                    const SizedBox(height: 20),
                                    TerminalLine(
                                      'locked.',
                                      cursor: true,
                                      style: DojiType.terminal.copyWith(fontSize: 17, height: 1.4),
                                    ),
                                  ],
                                  if (state.message case final msg? when state.locked) ...[
                                    const SizedBox(height: 12),
                                    TerminalLine(msg, tone: TerminalTone.tilt),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (state.locked) ...[
                          DojiButton(
                            label: 'unlock with $name',
                            semanticLabel: 'Unlock with $name',
                            variant: DojiButtonVariant.secondary,
                            icon: Icon(kind?.icon ?? Icons.lock_outline_rounded),
                            autofocus: true,
                            onPressed: state.authenticating ? null : () => unawaited(lock.unlock()),
                          ),
                          if (fallback != null) ...[
                            const SizedBox(height: 12),
                            DojiButton(
                              label: fallback,
                              variant: DojiButtonVariant.text,
                              size: DojiButtonSize.small,
                              onPressed: state.authenticating
                                  ? null
                                  : () => unawaited(lock.unlock(fallback: true)),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

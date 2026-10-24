import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'home_controller.dart';

/// Close your day (Doji Home › 02): two prompts and a mindset score. Saving
/// lights today's square on Home.
///
/// TODO(next-slice): save the reflection and score to the journal.
class CloseDayScreen extends ConsumerStatefulWidget {
  const CloseDayScreen({super.key});

  @override
  ConsumerState<CloseDayScreen> createState() => _CloseDayScreenState();
}

class _CloseDayScreenState extends ConsumerState<CloseDayScreen> {
  final _plan = TextEditingController();
  final _differently = TextEditingController();
  double _mindset = 7;

  @override
  void dispose() {
    _plan.dispose();
    _differently.dispose();
    super.dispose();
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.home);

  void _close() {
    unawaited(ref.read(hapticsProvider).light());
    ref
        .read(homeControllerProvider.notifier)
        .closeDay(wentToPlan: _plan.text, doDifferently: _differently.text, mindset: _mindset.round());
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: margin - 8, vertical: 4),
                    child: DojiButton(
                      label: 'home',
                      variant: DojiButtonVariant.text,
                      size: DojiButtonSize.small,
                      expand: false,
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _leave,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const TerminalLine('close your day', liveRegion: false),
                        const SizedBox(height: 10),
                        Semantics(
                          header: true,
                          child: Text('how did today go?', style: DojiType.largeTitle.copyWith(fontSize: 32)),
                        ),
                        const SizedBox(height: 18),
                        _Prompt(
                          label: 'what went to plan?',
                          hint: 'one or two lines is enough',
                          controller: _plan,
                        ),
                        const SizedBox(height: 18),
                        _Prompt(
                          label: 'what would you do differently?',
                          hint: 'no judgement, just notes',
                          controller: _differently,
                        ),
                        const SizedBox(height: 18),
                        DojiSlider(
                          label: 'mindset score',
                          value: _mindset,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          format: (v) => '${v.round()}/10',
                          onChanged: (v) => setState(() => _mindset = v),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(margin, 0, margin, 16),
                  child: DojiButton(label: 'close the day', onPressed: _close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.label, required this.hint, required this.controller});

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
      const SizedBox(height: 8),
      DojiTextField(
        controller: controller,
        hint: hint,
        large: false,
        minLines: 3,
        maxLines: 5,
        semanticLabel: label,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
      ),
    ],
  );
}

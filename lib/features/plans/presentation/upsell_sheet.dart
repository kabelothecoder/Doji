import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/plans.dart';

/// Design system: `UpsellSheet` (Doji Plans spec). Half-height frosted sheet:
/// radius 24 top, blur 30, #17191C at 80%. Dismiss by the close button,
/// "not now", the barrier, swipe down or the back gesture. The call to action
/// opens plans with [target] preselected.
///
/// Callers show a given trigger at most once per day.
class UpsellSheet extends StatelessWidget {
  const UpsellSheet({
    super.key,
    required this.tag,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.target,
    required this.onDismiss,
    this.accessory,
  });

  final String tag;
  final String title;
  final String body;
  final String ctaLabel;
  final PlanId target;
  final Widget? accessory;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: GlassSurface(
          radius: DojiRadius.sheet,
          tint: DojiColors.elevated2,
          fillOpacity: 0.8,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3D42),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TerminalLine(
                          tag,
                          liveRegion: false,
                          style: DojiType.hint.copyWith(fontSize: 12),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(10, 0),
                        child: DojiIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'Close',
                          outlined: false,
                          background: Colors.transparent,
                          foreground: DojiColors.textSecondary,
                          onPressed: onDismiss,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(title, style: DojiType.headline.copyWith(fontSize: 24, letterSpacing: -0.48)),
                  ),
                  const SizedBox(height: 12),
                  Text(body, style: DojiType.callout.copyWith(fontSize: 16)),
                  if (accessory != null) ...[const SizedBox(height: 12), accessory!],
                  const SizedBox(height: 24),
                  DojiButton(
                    label: ctaLabel,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(context.push('${Routes.plans}?plan=${target.name}'));
                    },
                  ),
                  const SizedBox(height: 4),
                  DojiButton(
                    label: 'not now',
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The three triggers in the handoff. Values that depend on the person
/// ([resetsAt], [resetsOn], minutes) are passed in, never invented here.
enum UpsellKind { aiBrief, streak, voice }

/// Opens the sheet for [kind]. [resetsAt] is the time of day the next brief
/// unlocks ("07:30"); [resetsOn] is the date voice minutes reset ("3 nov").
Future<void> showUpsellSheet(
  BuildContext context, {
  required UpsellKind kind,
  String resetsAt = '',
  String resetsOn = '',
  int voiceMinutes = 60,
}) {
  final content = switch (kind) {
    UpsellKind.aiBrief => (
      tag: 'ai brief · 1/1 used today',
      title: "you've used today's ai brief.",
      body:
          'the next one unlocks tomorrow${resetsAt.isEmpty ? '' : ' at $resetsAt'}. '
          'basic gives you unlimited briefs and chat, and remembers your setups.',
      cta: 'see basic',
      target: PlanId.basic,
      streak: false,
    ),
    UpsellKind.streak => (
      tag: 'streak · 7 days',
      title: '7-day streak — keep it going with pro.',
      body:
          'seven squares, each a day you kept your word. pro adds guard and the voice coach '
          'for the days that test it.',
      cta: 'try pro free for $trialDays days',
      target: PlanId.pro,
      streak: true,
    ),
    UpsellKind.voice => (
      tag: 'voice coach · $voiceMinutes/$voiceMinutes min used',
      title: 'voice minutes used.',
      body:
          'text coaching stays on. minutes reset${resetsOn.isEmpty ? '' : ' on $resetsOn'}, '
          'or elite prop includes voice coaching under fair use.',
      cta: 'see elite prop',
      target: PlanId.elite,
      streak: false,
    ),
  };
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: DojiMotion.reduced(context)
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : null,
    builder: (sheetContext) => UpsellSheet(
      tag: content.tag,
      title: content.title,
      body: content.body,
      ctaLabel: content.cta,
      target: content.target,
      accessory: content.streak ? const _SevenSquares() : null,
      onDismiss: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _SevenSquares extends StatelessWidget {
  const _SevenSquares();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '7 lit squares',
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: DojiColors.dojiGreen, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ],
      ),
    ),
  );
}

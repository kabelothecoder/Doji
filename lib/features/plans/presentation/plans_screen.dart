import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/layout.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../domain/plans.dart';
import 'plans_controller.dart';
import 'widgets/billing_toggle.dart';
import 'widgets/plan_card.dart';
import 'widgets/plans_footer.dart';
import 'widgets/trial_timeline.dart';

/// Handoff "plans screen": shown once the setup is saved, and from every
/// upsell. The recommended plan (from onboarding) is first, selected and open.
///
/// Phones: one scrolling column with a pinned call to action. Windows: a
/// modal over the workspace, four plans side by side, Esc closes.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.preselect});

  /// Plan the upsell that opened this screen points at.
  final PlanId? preselect;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.preselect;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(plansControllerProvider.notifier).preselect(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      },
      child: Scaffold(
        backgroundColor: DojiColors.bg,
        body: Stack(
          children: [
            const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
            wide ? const _WideLayout() : const _PhoneLayout(),
          ],
        ),
      ),
    );
  }
}

List<(String, String)> _profileLines(ProfileDoji p) => [
  ('name', p.name ?? 'trader'),
  if (p.style != null) ('style', p.style!),
  if (p.instruments.isNotEmpty) ('markets', p.instruments.map(instrumentLabel).join(', ')),
  if (p.goal != null) ('goal', p.goal!),
  if (p.struggles.isNotEmpty) ('struggles', p.struggles.join(', ')),
];

final _profileProvider = Provider.autoDispose<ProfileDoji>(
  (ref) => ref.watch(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji(),
);

class _PhoneLayout extends ConsumerWidget {
  const _PhoneLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(plansControllerProvider);
    final c = ref.read(plansControllerProvider.notifier);
    final lines = _profileLines(ref.watch(_profileProvider));
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final target = DojiTokens.of(context).minTarget;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(margin, 12, margin, 20),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: target),
                      child: Row(
                        children: [
                          const Expanded(
                            child: TerminalLine('setup saved', tone: TerminalTone.muted, liveRegion: false),
                          ),
                          Transform.translate(
                            offset: const Offset(8, 0),
                            child: DojiButton(
                              label: 'continue free',
                              variant: DojiButtonVariant.text,
                              size: DojiButtonSize.small,
                              expand: false,
                              onPressed: () => context.go(Routes.home),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text('your doji is configured.', style: DojiType.largeTitle),
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(lines: lines),
                    const SizedBox(height: 16),
                    BillingToggle(value: s.period, onChanged: c.setPeriod),
                    for (final id in planOrder(s.recommended)) ...[
                      const SizedBox(height: 16),
                      PlanCard(
                        plan: planOf(id),
                        period: s.period,
                        selected: s.selected == id,
                        expanded: s.expanded == id,
                        recommended: id == s.recommended,
                        reason: recommendationReason(id),
                        onTap: () => c.pick(id),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DojiButton(
                      label: 'compare all plans',
                      variant: DojiButtonVariant.outline,
                      size: DojiButtonSize.regular,
                      icon: const Icon(Icons.table_rows_outlined),
                      onPressed: () => unawaited(context.push(Routes.planCompare)),
                    ),
                    if (s.paid) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DojiColors.elevated1,
                          borderRadius: BorderRadius.circular(DojiRadius.card),
                          border: Border.all(color: DojiColors.separator),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HOW THE TRIAL WORKS', style: DojiType.label),
                            const SizedBox(height: 12),
                            TrialTimeline(
                              planName: planOf(s.selected).name,
                              price: planOf(s.selected).usd(s.period),
                            ),
                            Text(TrialTimeline.reminder, style: DojiType.callout.copyWith(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const PlansFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// `profile.doji`: the saved answers the recommendation came from.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.lines});

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'profile dot doji. ${lines.map((l) => '${l.$1}: ${l.$2}').join('. ')}',
    child: ExcludeSemantics(
      child: GlassSurface(
        radius: DojiRadius.sheet,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: DojiColors.dojiGreen),
                const SizedBox(width: 8),
                Text('profile.doji', style: DojiType.config.copyWith(color: DojiColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: DojiType.config.copyWith(color: DojiColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: DojiType.config.copyWith(color: DojiColors.textPrimary, height: 1.45),
                          children: [
                            TextSpan(
                              text: '${lines[i].$1}: ',
                              style: const TextStyle(color: DojiColors.textSecondary),
                            ),
                            TextSpan(text: lines[i].$2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Windows: "unlock the engine." as a modal over the workspace.
class _WideLayout extends ConsumerWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(plansControllerProvider);
    final c = ref.read(plansControllerProvider.notifier);
    final p = ref.watch(_profileProvider);
    final summary = _profileLines(p).map((l) => l.$2).join(' · ');
    final selected = planOf(s.selected);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: GlassSurface(
              radius: DojiRadius.sheet,
              tint: DojiColors.elevated2,
              fillOpacity: 0.82,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TerminalLine('setup saved', liveRegion: false),
                            const SizedBox(height: 10),
                            Semantics(
                              header: true,
                              child: Text('unlock the engine.', style: DojiType.hero.copyWith(fontSize: 40)),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: DojiType.config.copyWith(height: 1.5),
                                children: [
                                  const TextSpan(text: 'profile.doji · '),
                                  TextSpan(
                                    text: summary,
                                    style: const TextStyle(color: DojiColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 300,
                        child: BillingToggle(value: s.period, onChanged: c.setPeriod),
                      ),
                      const SizedBox(width: 16),
                      DojiIconButton(
                        icon: Icons.close_rounded,
                        semanticLabel: 'Close',
                        outlined: false,
                        background: Colors.transparent,
                        foreground: DojiColors.textSecondary,
                        onPressed: () => context.go(Routes.home),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final plan in plans) ...[
                          if (plan.id != PlanId.free) const SizedBox(width: 12),
                          Expanded(
                            child: PlanCard(
                              plan: plan,
                              period: s.period,
                              selected: s.selected == plan.id,
                              expanded: true,
                              recommended: plan.id == s.recommended,
                              reason: recommendationReason(plan.id),
                              onTap: () => c.select(plan.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: s.paid
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TrialTimeline(
                                    planName: selected.name,
                                    price: selected.usd(s.period),
                                    axis: Axis.horizontal,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    TrialTimeline.reminder,
                                    style: DojiType.callout.copyWith(fontSize: 13),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 380,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DojiButton(
                              label: s.paid ? 'continue to checkout' : 'continue with free',
                              size: DojiButtonSize.regular,
                              autofocus: true,
                              onPressed: s.busy ? null : () => unawaited(runCheckout(context, ref)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              termsLine(s.selected, s.period, storeName: storeName),
                              style: DojiType.hint.copyWith(fontFamily: DojiFonts.sans, height: 1.45),
                            ),
                            const Row(
                              children: [
                                PlansLinks(),
                                Spacer(),
                                KeyHints(['esc to close']),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

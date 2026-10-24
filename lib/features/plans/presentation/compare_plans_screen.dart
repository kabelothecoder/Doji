import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/plans.dart';
import 'plans_controller.dart';
import 'widgets/plan_compare_table.dart';
import 'widgets/plans_footer.dart';

/// Handoff "compare all plans": the full matrix with the plan header pinned.
/// Tapping a column selects that plan; the call to action follows the choice.
class ComparePlansScreen extends ConsumerWidget {
  const ComparePlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(plansControllerProvider);
    final c = ref.read(plansControllerProvider.notifier);
    void back() => context.canPop() ? context.pop() : context.go(Routes.plans);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): back},
      child: Scaffold(
        backgroundColor: DojiColors.bg,
        body: Stack(
          children: [
            const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      SizedBox(
                        height: DojiTokens.of(context).minTarget,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: DojiButton(
                                  label: 'plans',
                                  variant: DojiButtonVariant.text,
                                  size: DojiButtonSize.small,
                                  expand: false,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                                  onPressed: back,
                                ),
                              ),
                            ),
                            Semantics(
                              header: true,
                              child: Text(
                                'compare plans',
                                style: DojiType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PlanCompareTable(selected: s.selected, period: s.period, onSelect: c.select),
                      ),
                      PlansFooter(
                        showLinks: false,
                        ctaLabel: s.paid
                            ? 'try ${planOf(s.selected).name} free for $trialDays days'
                            : 'continue with free',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

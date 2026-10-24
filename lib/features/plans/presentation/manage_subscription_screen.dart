import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../data/billing_repository.dart';
import '../domain/plans.dart';
import 'plans_controller.dart';

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Handoff "settings · manage subscription". Cancelling happens in the
/// store, so that row opens the store's subscription page. Everything the
/// person made (journal, mood log, grid) stays on free.
class ManageSubscriptionScreen extends ConsumerWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entitlementProvider);
    final plan = planOf(e.plan);
    final renews = e.trialEndsAt == null ? '—' : _date(e.trialEndsAt!);
    void back() => context.canPop() ? context.pop() : context.go(Routes.settings);

    return AuthScaffold(
      leading: AuthLeading.back,
      onLeading: back,
      bodyGap: 0,
      body: [
        Semantics(header: true, child: Text('subscription', style: DojiType.largeTitle)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DojiColors.elevated1,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: DojiColors.separator),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CURRENT PLAN', style: DojiType.label),
              const SizedBox(height: 12),
              Text(plan.name, style: DojiType.title.copyWith(fontSize: 24)),
              const SizedBox(height: 12),
              _Fact('price', '${plan.usd(e.period)} · ${plan.zar(e.period)}'),
              if (!plan.isFree) _Fact(e.isTrial ? 'trial ends' : 'renews', renews),
              _Fact('billed by', storeName),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Group(
          rows: [
            _Action(
              label: plan.isFree ? 'see plans' : 'change plan',
              onTap: () => unawaited(context.push(Routes.planCompare)),
            ),
            if (!plan.isFree && e.period == BillingPeriod.monthly)
              _Action(
                label: 'switch to annual',
                note: annualNote,
                onTap: () => unawaited(ref.read(billingRepositoryProvider).openStoreSubscriptions()),
              ),
            if (!plan.isFree)
              _Action(
                label: 'cancel subscription',
                sub: 'opens $storeName subscriptions',
                trailing: Icons.open_in_new_rounded,
                onTap: () => unawaited(ref.read(billingRepositoryProvider).openStoreSubscriptions()),
              ),
            _Action(
              label: 'restore purchases',
              trailing: null,
              onTap: () => unawaited(ref.read(entitlementProvider.notifier).restore()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!plan.isFree)
          Text(
            'if you cancel, you keep ${plan.name} until $renews. your journal, mood log and grid stay on free.',
            style: DojiType.callout.copyWith(fontSize: 14),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DojiType.config.copyWith(fontSize: 13, color: DojiColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: DojiType.config.copyWith(fontSize: 13, color: DojiColors.textPrimary),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DojiRadius.card),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        border: Border.all(color: DojiColors.separator),
        borderRadius: BorderRadius.circular(DojiRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: DojiColors.separator)),
              ),
              child: rows[i],
            ),
        ],
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    this.note,
    this.sub,
    this.trailing = Icons.chevron_right_rounded,
  });

  final String label;
  final String? note;
  final String? sub;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onTap,
    pressedScale: 1,
    semanticLabel: [label, ?note, ?sub].join(', '),
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: DojiType.body.copyWith(fontSize: 16)),
                    if (note != null) Text(note!, style: DojiType.hint.copyWith(color: DojiColors.dojiGreen)),
                  ],
                ),
                if (sub != null) Text(sub!, style: DojiType.callout.copyWith(fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, size: 20, color: DojiColors.textSecondary),
        ],
      ),
    ),
  );
}

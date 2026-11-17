import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../domain/trading_account.dart';
import 'accounts_controller.dart';

/// The trader's accounts: switch the active one, add, open the editor,
/// delete (asks first). No design file exists for it (design/SOURCE.md ›
/// Missing); it is built from design-system parts.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountsControllerProvider);
    final active = profile.activeAccount?.id;
    final ctrl = ref.read(accountsControllerProvider.notifier);
    void back() => context.canPop() ? context.pop() : context.go(Routes.settings);

    Future<void> add() async {
      final account = AccountsController.blank(AccountKind.personal);
      await ctrl.save(account);
      if (context.mounted) unawaited(context.push(Routes.accountEditor(account.id)));
    }

    return AuthScaffold(
      leading: AuthLeading.back,
      onLeading: back,
      bodyGap: 0,
      body: [
        Semantics(header: true, child: Text('accounts', style: DojiType.largeTitle)),
        const SizedBox(height: 8),
        Text(
          'each account keeps its own rules and strategy. home, the journal, the brief and the coach read the active one.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 20),
        for (final a in profile.accounts) ...[
          _AccountCard(
            account: a,
            active: a.id == active,
            onSwitch: a.id == active ? null : () => unawaited(ctrl.switchTo(a.id)),
            onEdit: () => unawaited(context.push(Routes.accountEditor(a.id))),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        DojiButton(
          label: 'add an account',
          variant: DojiButtonVariant.secondary,
          icon: const Icon(Icons.add_rounded, size: 20),
          onPressed: () => unawaited(add()),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.active,
    required this.onSwitch,
    required this.onEdit,
  });

  final TradingAccount account;
  final bool active;
  final VoidCallback? onSwitch;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final r = account.rules;
    final facts = [
      account.kind.label,
      account.accountCurrency,
      if (r?.riskPerTrade != null) '${r!.riskPerTrade}% a trade',
      if (r?.maxTradesPerDay != null) 'max ${r!.maxTradesPerDay} a day',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: active ? DojiColors.dojiGreen : DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(account.name, style: DojiType.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              // Colour is never the only signal: the word says it.
              if (active)
                Text('ACTIVE', style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.dojiGreen)),
            ],
          ),
          const SizedBox(height: 4),
          Text(facts, style: DojiType.callout),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onSwitch != null) ...[
                Expanded(
                  child: DojiButton(
                    label: 'make active',
                    size: DojiButtonSize.small,
                    semanticLabel: 'make ${account.name} active',
                    onPressed: onSwitch,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: DojiButton(
                  label: 'edit',
                  size: DojiButtonSize.small,
                  variant: DojiButtonVariant.secondary,
                  semanticLabel: 'edit ${account.name}',
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

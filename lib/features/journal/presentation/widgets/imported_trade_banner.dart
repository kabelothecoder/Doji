import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/insights_repository.dart';
import '../../domain/insights.dart';
import '../../domain/trade.dart';
import '../journal_controller.dart';
import '../review_sheet.dart';

/// The newest imported trade still waiting for a review, unless put off with "later".
final pendingImportProvider = Provider.autoDispose<Trade?>((ref) {
  final later = ref.watch(insightPrefsProvider.select((p) => p.later));
  return ref
      .watch(activeAccountTradesProvider)
      .where((t) => t.source != 'manual' && !t.reviewed && !later.contains(t.id))
      .fold<Trade?>(null, (best, t) => best == null || t.closedAt.isAfter(best.closedAt) ? t : best);
});

/// "new trade imported · XAUUSD long · −1R" with review · 20 sec / later
/// (design: Doji Trade Journal Phone › imported).
class ImportedTradeBanner extends ConsumerWidget {
  const ImportedTradeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(pendingImportProvider);
    if (t == null) return const SizedBox.shrink();
    final result = switch (t.r) {
      final r? => rText(r),
      null => t.isLoss ? 'a loss' : (t.isWin ? 'a gain' : 'flat'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.dojiGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalLine(
            'new trade imported · ${t.symbol} ${t.direction.label} · $result',
            tone: TerminalTone.primary,
            cursor: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DojiButton(
                  label: 'review · 20 sec',
                  size: DojiButtonSize.regular,
                  onPressed: () => unawaited(showReviewSheet(context, t)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DojiButton(
                  label: 'later',
                  variant: DojiButtonVariant.outline,
                  size: DojiButtonSize.regular,
                  onPressed: () => ref.read(insightPrefsProvider.notifier).later(t.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

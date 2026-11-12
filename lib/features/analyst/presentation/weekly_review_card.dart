import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/widgets/home_card.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/presentation/brief_chat_sheet.dart';
import 'analyst_controller.dart';

/// "WEEKLY REVIEW": last week, written from the journal's own counts. Asks for
/// the review on first show; "focus on this" makes its rule this week's.
class WeeklyReviewCard extends ConsumerStatefulWidget {
  const WeeklyReviewCard({super.key});

  @override
  ConsumerState<WeeklyReviewCard> createState() => _WeeklyReviewCardState();
}

class _WeeklyReviewCardState extends ConsumerState<WeeklyReviewCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = ref.read(journalProfileProvider).activeAccount?.id;
      if (id == null) return;
      unawaited(ref.read(reviewsProvider.notifier).ensureLastWeek(id, ref.read(activeAccountTradesProvider)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(latestReviewProvider);
    final focus = ref.watch(focusRuleProvider);
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeEyebrow('WEEKLY REVIEW'),
          const SizedBox(height: 10),
          if (review == null)
            const TerminalLine('reading last week…', cursor: true, liveRegion: false)
          else ...[
            Text('week of ${review.weekStart.day}/${review.weekStart.month}', style: DojiType.hint),
            const SizedBox(height: 10),
            _Part(title: 'what you kept', text: review.kept),
            const SizedBox(height: 10),
            _Part(title: 'what you broke', text: review.broke),
            if (review.focusRule case final rule?) ...[
              const SizedBox(height: 10),
              _Part(title: 'one rule for next week', text: rule),
              const SizedBox(height: 12),
              if (review.accepted)
                TerminalLine(
                  focus == null ? 'focus taken for that week.' : 'focus for this week. it shows on home.',
                  tone: TerminalTone.primary,
                )
              else
                DojiButton(
                  label: 'focus on this rule',
                  size: DojiButtonSize.small,
                  onPressed: () => unawaited(ref.read(reviewsProvider.notifier).accept(review)),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: DojiType.label.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Text(text, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
      ],
    ),
  );
}

/// "ask the analyst": the shared chat sheet over the trader's own numbers.
Future<void> showAnalystChatSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x8C000000),
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: DojiMotion.reduced(context)
      ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
      : null,
  builder: (_) => ChatSheet(
    title: 'ask the analyst',
    scope: 'reads your journal, chart notes, backtests and practice on this account',
    hint: 'ask about your trading',
    fieldLabel: 'question for the analyst',
    footer: 'Counted from your own trades. Not financial advice.',
    followUps: const [
      'when do i break my max trades?',
      'what happens after a loss?',
      'how close am i to my payout rules?',
    ],
    watch: (ref) => ref.watch(analystChatControllerProvider),
    controller: (ref) => ref.read(analystChatControllerProvider.notifier),
  ),
);

/// The focus rule line on Home and in the rail.
class FocusRuleLine extends ConsumerWidget {
  const FocusRuleLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(focusRuleProvider);
    if (rule == null) return const SizedBox.shrink();
    return TerminalLine('focus this week: $rule', tone: TerminalTone.primary, liveRegion: false);
  }
}

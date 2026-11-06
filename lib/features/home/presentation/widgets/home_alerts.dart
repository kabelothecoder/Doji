import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/home_models.dart';
import 'home_card.dart';

/// Design spec `TiltBanner`: shown after 2 losses in a row. Orange shape +
/// copy + "talk to coach". Dismissing keeps the state in the rules card.
class TiltBanner extends StatelessWidget {
  const TiltBanner({super.key, required this.losses, required this.lossesToCooldown, required this.onCoach});

  final int losses;
  final int lossesToCooldown;
  final VoidCallback onCoach;

  @override
  Widget build(BuildContext context) {
    final left = lossesToCooldown - losses;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$losses losses today. ${left <= 1 ? 'one more' : '$left more'} and cooldown starts.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DojiColors.orangeTint,
          borderRadius: BorderRadius.circular(DojiRadius.card),
          border: Border.all(color: DojiColors.orangeHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 22, color: DojiColors.tiltOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$losses losses today. ${left <= 1 ? 'one more' : '$left more'} and cooldown starts.',
                      style: DojiType.body.copyWith(fontSize: 16, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DojiButton(
              label: 'talk to coach',
              variant: DojiButtonVariant.caution,
              size: DojiButtonSize.small,
              onPressed: onCoach,
            ),
          ],
        ),
      ),
    );
  }
}

/// Design spec `CloseDayCard`, the evening form: opens the 2-prompt reflection
/// and mindset score.
class CloseDayCard extends StatelessWidget {
  const CloseDayCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => HomeCard(
    padding: const EdgeInsets.all(18),
    borderColor: DojiColors.dojiGreen.withValues(alpha: 0.45),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TerminalLine('evening', tone: TerminalTone.muted, liveRegion: false),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text('close your day.', style: DojiType.headline.copyWith(fontSize: 22)),
        ),
        const SizedBox(height: 10),
        Text(
          "two prompts and a mindset score. today's square fills when you're done.",
          style: DojiType.callout,
        ),
        const SizedBox(height: 14),
        DojiButton(label: 'close your day', size: DojiButtonSize.regular, onPressed: onStart),
      ],
    ),
  );
}

/// `CloseDayCard`, the done form: "day closed".
class DayClosedCard extends StatelessWidget {
  const DayClosedCard({super.key});

  @override
  Widget build(BuildContext context) => const HomeCard(
    padding: EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalLine('day closed.', tone: TerminalTone.primary, cursor: true, liveRegion: false),
        SizedBox(height: 6),
        _ClosedCopy(),
      ],
    ),
  );
}

class _ClosedCopy extends StatelessWidget {
  const _ClosedCopy();

  @override
  Widget build(BuildContext context) =>
      Text("today's square is lit. see you at the open.", style: DojiType.callout);
}

/// Normal-day entry to the evening reflection, below the cards.
class CloseDayRow extends StatelessWidget {
  const CloseDayRow({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onStart,
    semanticLabel: 'close your day, from $eveningFromHour:00, 2 prompts and mindset',
    borderRadius: BorderRadius.circular(DojiRadius.card),
    child: HomeCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.bedtime_outlined, size: 22, color: DojiColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'close your day',
                  style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text('from $eveningFromHour:00 · 2 prompts + mindset', style: DojiType.hint),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: DojiColors.textTertiary),
        ],
      ),
    ),
  );
}

/// Design spec `RuleMeter` card: "RULES TODAY" with the log-a-trade link.
class RulesTodayCard extends StatelessWidget {
  const RulesTodayCard({super.key, required this.usage, required this.onLogTrade, this.note});

  final List<RuleUsage> usage;

  /// Where the account figures come from (broker, as of when), if linked.
  final String? note;
  final VoidCallback onLogTrade;

  @override
  Widget build(BuildContext context) => HomeCard(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: HomeEyebrow('RULES TODAY')),
            Transform.translate(
              offset: const Offset(8, 0),
              child: DojiButton(
                label: 'log a trade',
                variant: DojiButtonVariant.ghost,
                size: DojiButtonSize.small,
                expand: false,
                onPressed: onLogTrade,
              ),
            ),
          ],
        ),
        for (var i = 0; i < usage.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          RuleMeter(label: usage[i].label, used: usage[i].used, limit: usage[i].limit, unit: usage[i].unit),
        ],
        if (note != null) ...[
          const SizedBox(height: 12),
          Text(note!, style: DojiType.hint.copyWith(fontSize: 11, height: 1.5)),
        ],
      ],
    ),
  );
}

/// The compact latest-insight card (Doji Insight Card, variant compact).
///
/// PLACEHOLDER: the real card comes with the journal.
/// TODO(next-slice): latest insight from the journal; no invented figures.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DojiPressable(
    onPressed: onTap,
    semanticLabel: 'latest insight from your journal: your trades after 3pm cost you [x] R this month',
    borderRadius: BorderRadius.circular(DojiRadius.card),
    child: HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATEST INSIGHT · JOURNAL', style: DojiType.label),
          const SizedBox(height: 10),
          Text(
            'your trades after 3pm cost you [x]R this month',
            style: DojiType.body.copyWith(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('[n] trades', style: DojiType.hint),
              const Spacer(),
              Text(
                'see the trades',
                style: DojiType.callout.copyWith(fontSize: 13, color: DojiColors.dojiGreen),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

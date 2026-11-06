import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
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
import '../../app_lock/presentation/app_lock_controller.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/market_format.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/user_zone.dart';
import '../domain/home_models.dart';
import 'home_controller.dart';
import 'post_trade_sheet.dart';
import 'widgets/ai_brief_card.dart';
import 'widgets/home_alerts.dart';
import 'widgets/home_card.dart';
import 'widgets/home_header.dart';
import 'widgets/mini_grid.dart';
import 'widgets/setup_checklist.dart';
import 'widgets/open_card.dart';

/// Content width from which the rail docks beside the column (360 + margins +
/// a 480 column).
const double _dockRailFrom = 880;

/// Home: the main screen after plans (design: Doji Home.dc.html).
///
/// States, all derived: day zero (checklist day), normal, tilt (2 losses),
/// evening (close your day) and day closed. Phones get one scrolling column
/// under the bottom bar; wide screens and Windows get the same column beside
/// the docked [DojiRailPanel].
///
/// Trades taken, daily loss, tilt and the prop drawdown come from the journal
/// ([HomeSnapshot.fromJournal]); the score, streak, brief and news are still
/// PLACEHOLDER.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _railOpen = true;

  @override
  void initState() {
    super.initState();
    // Handoff A8a: offered once, on the second visit to Home.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final offer = await ref.read(appLockControllerProvider.notifier).shouldOffer();
      if (offer && mounted) unawaited(context.push(Routes.appLock));
    });
  }

  void _startOpen() {
    ref.read(homeControllerProvider.notifier).startOpen();
    unawaited(context.push(Routes.open));
  }

  /// Log a trade: the journal's manual add, then its review.
  void _logTrade() => unawaited(context.push(Routes.addTrade));

  /// The rail's "log emotion" (Ctrl+Shift+D): how the last trade felt.
  void _logEmotion() =>
      unawaited(showPostTradeSheet(context, instrument: ref.read(homeSnapshotProvider).instruments.first));

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final snap = ref.watch(homeSnapshotProvider);
    final state = ref.watch(homeControllerProvider);
    final profile = ref.watch(homeProfileProvider);
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    // The docked rail shows the first instrument's brief (the same one as 1b).
    final railBrief = wide ? ref.watch(pairBriefProvider(snap.instruments.first)).value : null;
    final zone = userZoneFromProfile(profile);

    final evening = isEvening();
    final zero = isDayZero(profile);
    final days = sampleGrid(today: clock.now(), zero: zero, closed: state.dayClosed);
    final todayIndex = 11 * 7 + (clock.now().weekday - 1);

    final cards = <Widget>[
      // TODO(next-slice): pass onBell once the notification centre exists.
      HomeHeader(name: snap.name, rank: snap.rank, evening: evening),
      if (snap.tilt)
        TiltBanner(
          losses: snap.losses,
          lossesToCooldown: snap.lossesToCooldown,
          onCoach: () => context.push(Routes.coach),
        ),
      if (state.dayClosed)
        const DayClosedCard()
      else if (evening)
        CloseDayCard(onStart: () => unawaited(context.push(Routes.closeDay))),
      if (zero) ...[
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MiniGrid(days: days, todayIndex: todayIndex, label: 'doji grid, first day lit'),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: DojiType.callout.copyWith(color: DojiColors.textPrimary, height: 1.4),
                  children: [
                    const TextSpan(text: '1 day. '),
                    TextSpan(text: 'every square is a day you kept your word.', style: DojiType.callout),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!state.setupComplete)
          SetupChecklist(
            done: state.doneTasks,
            onToggle: ref.read(homeControllerProvider.notifier).toggleTask,
          ),
        DojiChoiceChip(
          label: 'tomorrow at ${tomorrowOpenTime(profile)}: the open',
          selected: false,
          dashed: true,
          onTap: _startOpen,
        ),
      ] else ...[
        _ScoreGridCard(snap: snap, days: days, todayIndex: todayIndex),
        OpenCard(doneAt: state.openDoneAt, mood: state.mood, onStart: _startOpen),
        AiBriefCard(instruments: snap.instruments),
        RulesTodayCard(usage: snap.usage, note: snap.accountNote, onLogTrade: _logTrade),
        InsightCard(onTap: () => context.go(Routes.journal)),
        if (!evening && !state.dayClosed)
          CloseDayRow(onStart: () => unawaited(context.push(Routes.closeDay))),
      ],
      if (profile.pendingSync)
        const TerminalLine('profile.doji lives on this device. sign in anytime to sync.'),
      if (kDebugMode) const _DebugControls(),
    ];

    final column = ListView.separated(
      padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => cards[i],
    );

    final body = wide
        ? LayoutBuilder(
            builder: (context, c) => c.maxWidth < _dockRailFrom
                // A narrow Windows window keeps the wide chrome but has no
                // room to dock the rail beside the column.
                // TODO(next-slice): offer the rail as a sheet here.
                ? Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: column),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: column,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 20, 24),
                        child: SizedBox(
                          width: 360,
                          child: _railOpen
                              ? DojiRailPanel(
                                  instrument: instrumentLabel(snap.instruments.first),
                                  strategyLine: railBrief == null
                                      ? 'measuring…'
                                      : '${railBrief.strategyName ?? 'your rules'} · '
                                            '${railBrief.metCount}/${railBrief.conditions.length} · '
                                            '${clockTime(zone, railBrief.updatedAt)}',
                                  conditionsMet:
                                      railBrief != null && railBrief.metCount == railBrief.conditions.length,
                                  onOpenBrief: () => context.push(Routes.pairDetail(snap.instruments.first)),
                                  meters: [
                                    for (final u in snap.usage)
                                      (label: u.label, used: u.used, limit: u.limit, unit: u.unit),
                                  ],
                                  tiltLevel: snap.tiltLevel,
                                  tiltWord: snap.tiltWord,
                                  // TODO(next-slice): next high-impact event from the calendar feed.
                                  nextNews: '[US CPI]',
                                  newsCountdown: '02:15:00',
                                  logged: state.lastEmotion,
                                  onLogEmotion: _logEmotion,
                                  onClose: () => setState(() => _railOpen = false),
                                )
                              : Align(
                                  alignment: Alignment.topRight,
                                  child: DojiButton(
                                    label: 'show rail',
                                    variant: DojiButtonVariant.outline,
                                    size: DojiButtonSize.small,
                                    expand: false,
                                    onPressed: () => setState(() => _railOpen = true),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          )
        : Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: column),
          );

    return CallbackShortcuts(
      bindings: {
        if (wide) const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): _logEmotion,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: DojiColors.bg,
          body: SafeArea(bottom: false, child: body),
        ),
      ),
    );
  }
}

/// Doji score, streak and the 12-week grid.
class _ScoreGridCard extends StatelessWidget {
  const _ScoreGridCard({required this.snap, required this.days, required this.todayIndex});

  final HomeSnapshot snap;
  final List<GridCellState> days;
  final int todayIndex;

  @override
  Widget build(BuildContext context) => HomeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: [
            Semantics(
              container: true,
              label: 'doji score ${snap.score}, sample data',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DOJI SCORE', style: DojiType.label.copyWith(fontSize: 11)),
                    Text('${snap.score}', style: DojiType.score.copyWith(fontSize: 52)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DojiColors.separator),
                ),
                child: Text('sample data', style: DojiType.hint.copyWith(fontSize: 10)),
              ),
            ),
            Semantics(
              container: true,
              label: 'streak ${snap.streak ?? '[n]'} days',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('STREAK', style: DojiType.label.copyWith(fontSize: 11)),
                    Text('${snap.streak ?? '[n]'} days', style: DojiType.data.copyWith(fontSize: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        MiniGrid(days: days, todayIndex: todayIndex, label: 'doji grid, last 12 weeks'),
        const SizedBox(height: 14),
        const GridLegend(),
      ],
    ),
  );
}

/// Debug builds only: start onboarding again. (Tilt now comes from the
/// journal's real losses, so there is no fake-loss switch any more.)
class _DebugControls extends ConsumerWidget {
  const _DebugControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      children: [
        DojiButton(
          label: 'reset onboarding (debug)',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          expand: false,
          onPressed: () async {
            await ref.read(onboardingControllerProvider.notifier).reset();
            ref.invalidate(homeProfileProvider);
            if (context.mounted) context.go(Routes.intro);
          },
        ),
      ],
    );
  }
}

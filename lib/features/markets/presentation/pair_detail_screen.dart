import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/haptics/doji_haptics.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/platform/reminders.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/domain/home_models.dart';
import '../../home/presentation/home_controller.dart';
import '../../onboarding/domain/user_zone.dart';
import '../../plans/presentation/upsell_sheet.dart';
import '../domain/candle.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';
import '../domain/market_format.dart';
import '../domain/market_status.dart';
import '../domain/pair_brief.dart';
import '../domain/strategy_reading.dart';
import '../domain/time_zones.dart';
import 'brief_chat_sheet.dart';
import 'markets_controller.dart';
import 'pair_detail_controller.dart';
import 'widgets/brief_chat_bar.dart';
import 'widgets/brief_section.dart';
import 'widgets/condition_list.dart';
import 'widgets/follow_up_chip.dart';
import 'widgets/pair_chart.dart';
import 'widgets/timeframe_tabs.dart';

/// Handoff 1b `PairDetailScreen` (Doji Hero Screens › Markets · pair detail):
/// price, the chart with the trader's own levels and the news window, and
/// the doji brief in five sections, with a floating "ask about this brief"
/// bar. No buy or sell anywhere; price is monochrome.
///
/// Prices, candles and news are SAMPLE data ([FakeMarketData],
/// [SampleNewsCalendar]) and say so on screen. On the free plan the brief's
/// written sections show for one instrument a day; the conditions and the
/// chart always show. Windows: Esc goes back.
///
/// States (Doji Core Tabs › 01b): loading (a cursor), market closed (the
/// chart dimmed, when it opens), feed error (try again) and no strategy yet.
class PairDetailScreen extends ConsumerStatefulWidget {
  const PairDetailScreen({super.key, required this.symbol, this.embedded = false});

  final String symbol;

  /// The markets list's second pane on wide screens: no back button and no Esc.
  final bool embedded;

  @override
  ConsumerState<PairDetailScreen> createState() => _PairDetailScreenState();
}

class _PairDetailScreenState extends ConsumerState<PairDetailScreen> {
  /// What happened when "remind me" was tapped.
  ReminderResult? _reminder;

  String get _symbol => instrumentBySymbol(widget.symbol)?.symbol ?? widget.symbol;

  @override
  void initState() {
    super.initState();
    // Opening the brief is what uses the free plan's one a day, and it ticks
    // "run your first ai brief" on Home's day-zero checklist.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(briefAccessProvider(_symbol).notifier).open();
      if (mounted && ref.read(briefAccessProvider(_symbol)).unlocked) {
        ref.read(homeControllerProvider.notifier).completeTask(SetupTask.brief);
      }
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.home);

  Future<void> _toggleWatch() => toggleWatchlist(context, ref, _symbol);

  /// After a feed error: ask for the price, the bars and the brief again.
  void _retry() {
    ref.invalidate(pairQuoteProvider(_symbol));
    ref.invalidate(pairCandlesProvider((_symbol, ref.read(pairTimeframeProvider(_symbol)))));
    ref.invalidate(pairBriefProvider(_symbol));
  }

  Future<void> _remind(CheckAgain check) async {
    final result = await ref.read(briefRemindersProvider.notifier).remind(_symbol, check);
    if (!mounted) return;
    setState(() => _reminder = result);
    if (result == ReminderResult.scheduled) unawaited(ref.read(hapticsProvider).light());
  }

  void _ask({String? question, bool listen = false}) {
    final access = ref.read(briefAccessProvider(_symbol));
    if (!access.unlocked) {
      unawaited(showUpsellSheet(context, kind: UpsellKind.aiBrief, resetsAt: '00:00'));
      return;
    }
    unawaited(showBriefChatSheet(context, symbol: _symbol, ask: question, listen: listen));
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _symbol;
    final name = displaySymbol(symbol);
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final quote = ref.watch(pairQuoteProvider(symbol));
    final brief = ref.watch(pairBriefProvider(symbol));
    final access = ref.watch(briefAccessProvider(symbol));
    final watching = ref.watch(watchlistProvider).any((s) => s.toUpperCase() == symbol.toUpperCase());
    TimeZones.ensureInitialized();
    final zone = userZoneFromProfile(ref.watch(marketsProfileProvider));
    final reminderAt = ref.watch(briefRemindersProvider)[symbol];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final setup = ref.watch(marketsProfileProvider).strategy?.parsed?.setup?.trim();

    final children = <Widget>[
      _Header(name: name, watching: watching, onBack: widget.embedded ? null : _back, onWatch: _toggleWatch),
      _PriceBlock(
        symbol: symbol,
        quote: quote,
        brief: brief.value,
        zone: zone,
        source: ref.watch(pairSourceProvider(symbol)),
      ),
      _ChartCard(symbol: symbol, name: name, brief: brief.value, onRetry: _retry),
      _BriefHeader(updatedAt: brief.value?.updatedAt, zone: zone),
      ...switch (brief) {
        AsyncData(:final value) => _briefSections(value, access, zone, reminderAt),
        AsyncError() => [
          const TerminalLine("couldn't build the brief.", tone: TerminalTone.tilt),
          DojiButton(
            label: 'try again',
            variant: DojiButtonVariant.outline,
            size: DojiButtonSize.small,
            expand: false,
            onPressed: () => ref.invalidate(pairBriefProvider(symbol)),
          ),
        ],
        _ => [
          TerminalLine(
            'reading the market against ${setup == null || setup.isEmpty ? 'your rules' : setup}',
            cursor: true,
          ),
        ],
      },
    ];

    return CallbackShortcuts(
      bindings: {if (!widget.embedded) const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Focus(
        autofocus: PlatformInfo.isDesktop && !widget.embedded,
        child: Scaffold(
          backgroundColor: DojiColors.bg,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView.separated(
                      // Room under the last line for the floating ask bar.
                      padding: EdgeInsets.fromLTRB(margin, 12, margin, 116 + 60 * scale),
                      itemCount: children.length,
                      separatorBuilder: (_, i) => SizedBox(height: i >= 3 ? 22 : 24),
                      itemBuilder: (_, i) => children[i],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 528),
                    child: BriefChatBar(onAsk: _ask, onVoice: () => _ask(listen: true)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _briefSections(PairBrief b, BriefAccess access, UserZone zone, DateTime? reminderAt) {
    final conditions = BriefSection(
      number: '03',
      title: 'YOUR ENTRY CONDITIONS',
      child: b.conditions.isEmpty
          ? const TerminalLine('no conditions to check yet. set your rules in your setup.', liveRegion: false)
          : ConditionList(conditions: b.conditions),
    );
    final check = b.checkAgain;
    final checkCard = check == null
        ? _DoneCard(dayDone: b.dayDone)
        : _CheckAgainCard(
            check: check,
            zone: zone,
            set: reminderAt != null && reminderAt == check.at,
            onRemind: () => _remind(check),
          );
    final reminderNote = switch (_reminder) {
      ReminderResult.scheduled when check != null => TerminalLine(
        'doji will remind you at ${clockDayTime(zone, check.at, now: b.updatedAt)}.',
        tone: TerminalTone.primary,
      ),
      ReminderResult.denied => const TerminalLine(
        'notifications are off for doji. turn them on in settings to get reminders.',
        tone: TerminalTone.tilt,
      ),
      ReminderResult.unavailable => const TerminalLine(
        "couldn't set a reminder on this device. check back at that time.",
        tone: TerminalTone.tilt,
      ),
      _ => null,
    };
    const disclaimer = Text(
      'Measured against your strategy. Not financial advice.',
      style: TextStyle(
        fontFamily: DojiFonts.sans,
        fontSize: 13,
        color: DojiColors.textSecondary,
        height: 1.4,
      ),
    );
    // No strategy yet: the rules are still measured; nothing is written.
    if (StrategyReading.of(ref.read(marketsProfileProvider).strategy?.parsed).kind == StrategyKind.none) {
      return [const _NoStrategyCard(), conditions, checkCard, ?reminderNote, disclaimer];
    }
    if (!access.unlocked) {
      return [
        _LockedBrief(usedOn: access.usedOn, onUnlock: () => _ask()),
        conditions,
        checkCard,
        ?reminderNote,
        disclaimer,
      ];
    }
    final strategyName = b.strategyName;
    return [
      BriefSection(number: '01', title: 'MARKET CONTEXT', text: b.context),
      BriefSection(
        number: '02',
        title: 'WHAT YOUR STRATEGY SAYS',
        text: b.strategy,
        trailing: strategyName == null ? null : StrategyChip(strategyName),
      ),
      conditions,
      BriefSection(number: '04', title: 'RISK NOTE', text: b.riskNote, tilt: true),
      checkCard,
      ?reminderNote,
      disclaimer,
      if (b.followUps.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in b.followUps)
              FollowUpChip(
                label: q,
                onPressed: () => _ask(question: q),
              ),
          ],
        ),
    ];
  }
}

/// Back · symbol · watchlist bookmark. Centred title on iOS and Windows;
/// left-aligned on Android (handoff: "title left-aligned").
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.watching, required this.onBack, required this.onWatch});

  final String name;
  final bool watching;

  /// Null in the wide layout's pane: the list is beside it.
  final VoidCallback? onBack;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final android = PlatformInfo.isAndroid;
    final title = Semantics(
      header: true,
      child: Text(
        name,
        textAlign: android ? TextAlign.start : TextAlign.center,
        style: DojiType.data.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    return Row(
      children: [
        if (onBack case final back?) ...[
          _GlassButton(
            icon: PlatformInfo.isIOS ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
            semanticLabel: 'back',
            onPressed: back,
          ),
          SizedBox(width: android ? 12 : 8),
        ],
        Expanded(child: title),
        const SizedBox(width: 8),
        _GlassButton(
          // Filled when watched: shape, not only colour.
          icon: watching ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: watching ? DojiColors.dojiGreen : DojiColors.textPrimary,
          semanticLabel: watching ? 'remove from watchlist' : 'add to watchlist',
          onPressed: onWatch,
        ),
      ],
    );
  }
}

/// A 44 glass circle (handoff 1b's back and bookmark).
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = DojiColors.textPrimary,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = DojiTokens.of(context).minTarget;
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: DojiPressable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox.square(
          dimension: size,
          child: GlassSurface(
            circle: true,
            blur: 24,
            tint: DojiColors.elevated2,
            fillOpacity: 0.7,
            child: Center(child: Icon(icon, size: 22, color: color)),
          ),
        ),
      ),
    );
  }
}

/// Price, "± % today", the session and news chips, and the sample label.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.symbol,
    required this.quote,
    required this.brief,
    required this.zone,
    required this.source,
  });

  /// Where the price comes from: the line under it says so.
  final FeedSource source;

  final String symbol;
  final AsyncValue<Quote?> quote;
  final PairBrief? brief;
  final UserZone zone;

  @override
  Widget build(BuildContext context) {
    final q = quote.value;
    final name = displaySymbol(symbol);
    final now = clock.now().toUtc();
    final status = MarketStatus.of(instrumentBySymbol(symbol), brief?.updatedAt ?? now);
    final news = brief?.nextNews;
    final when = brief?.updatedAt ?? now;
    final sessionText = switch (status) {
      AlwaysOpen() => 'OPEN 24/7',
      InSession(:final session, :final closesAt) =>
        '${session.label.toUpperCase()} · CLOSES ${clockDayTime(zone, closesAt, now: when).toUpperCase()}',
      OpenBetweenSessions() => 'OPEN',
      MarketClosed(:final opensAt) =>
        opensAt == null ? 'CLOSED' : 'CLOSED · OPENS ${clockDayTime(zone, opensAt, now: when).toUpperCase()}',
    };

    if (quote.hasValue && q == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('no prices for $name yet', style: DojiType.headline),
          const SizedBox(height: 6),
          Text('doji checks your rules for it; prices arrive with the live feed.', style: DojiType.callout),
        ],
      );
    }
    final price = q == null ? '—' : formatPrice(q.price, q.decimals);
    final change = q == null ? '' : formatChange(q.changePct);
    final spoken = q != null
        ? '$name $price, $change today, sample price'
        : quote.hasError
        ? '$name, price feed not responding'
        : '$name, loading price';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: spoken,
          child: ExcludeSemantics(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(price, style: DojiType.score.copyWith(fontSize: 44)),
                if (q != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '$change today',
                      style: DojiType.data.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: DojiColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(text: sessionText, dot: true),
            if (news != null)
              _Pill(text: 'NEWS ${clockDayTime(zone, news.at, now: when).toUpperCase()}', tilt: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(source.label, style: DojiType.hint),
      ],
    );
  }
}

/// The session and news chips: hairline pills, mono 12.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.dot = false, this.tilt = false});

  final String text;
  final bool dot;
  final bool tilt;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(DojiRadius.pill),
      border: Border.all(color: tilt ? DojiColors.orangeHairline : DojiColors.separator),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: DojiColors.textSecondary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: DojiType.hint.copyWith(color: tilt ? DojiColors.tiltOrange : DojiColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

/// Timeframe control, the chart and its time axis, on elevated-1.
class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.symbol, required this.name, required this.brief, required this.onRetry});

  final String symbol;
  final String name;
  final PairBrief? brief;

  /// Feed error: ask again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tf = ref.watch(pairTimeframeProvider(symbol));
    final candles = ref.watch(pairCandlesProvider((symbol, tf)));
    final quote = ref.watch(pairQuoteProvider(symbol));
    final decimals = quote.value?.decimals ?? 2;
    final now = brief?.updatedAt ?? clock.now().toUtc();
    final closed = switch (MarketStatus.of(instrumentBySymbol(symbol), now)) {
      MarketClosed(:final opensAt) => (opensAt: opensAt),
      _ => null,
    };
    final zone = userZoneFromProfile(ref.watch(marketsProfileProvider));
    final levels = brief?.levels;
    final news = brief?.nextNews;
    final overlays = [?levels?.spoken, if (news != null) 'the next news window'];
    final label = [
      'Candlestick chart for $name, ${tf.label}, ${ref.watch(pairSourceProvider(symbol)).live ? 'live prices' : 'sample prices'}',
      if (overlays.isNotEmpty) 'with ${overlays.join(' and ')}',
    ].join(', ');

    final list = candles.value ?? const <Candle>[];
    final times = list.isEmpty
        ? const <String>[]
        : [list.first, list[list.length ~/ 2], list.last].map((c) => _axisTime(c.at, tf, zone)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimeframeTabs(selected: tf, onChanged: ref.read(pairTimeframeProvider(symbol).notifier).set),
          const SizedBox(height: 12),
          if (candles.hasError || quote.hasError)
            _FeedError(onRetry: onRetry)
          else
            switch (candles) {
              AsyncData(:final value) when value.isEmpty => SizedBox(
                height: 200,
                child: Center(
                  child: Text('no chart for $name yet', style: DojiType.callout, textAlign: TextAlign.center),
                ),
              ),
              AsyncData(:final value) when closed != null => Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.4,
                    child: PairChart(
                      candles: value,
                      timeframe: tf,
                      decimals: decimals,
                      levels: levels,
                      news: news,
                      semanticLabel: '$label, market closed',
                    ),
                  ),
                  _ClosedTag(opensAt: closed.opensAt, zone: zone, now: now),
                ],
              ),
              AsyncData(:final value) => _OpenChart(
                symbol: symbol,
                child: PairChart(
                  candles: value,
                  timeframe: tf,
                  decimals: decimals,
                  levels: levels,
                  news: news,
                  semanticLabel: label,
                ),
              ),
              _ => SizedBox(
                height: 200,
                child: Center(child: TerminalLine('loading $name', cursor: true, liveRegion: false)),
              ),
            },
          if (times.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [for (final t in times) Text(t, style: DojiType.hint.copyWith(fontSize: 11))],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  /// hh:mm for intraday bars, 'jul 13' for H4 and D1.
  static String _axisTime(DateTime at, Timeframe tf, UserZone zone) {
    if (tf == Timeframe.h4 || tf == Timeframe.d1) {
      final d = onClock(zone, at);
      return '${_months[d.month - 1]} ${d.day}';
    }
    return clockTime(zone, at);
  }
}

/// "> doji brief_" and when it was worked out.
class _BriefHeader extends StatelessWidget {
  const _BriefHeader({required this.updatedAt, required this.zone});

  final DateTime? updatedAt;
  final UserZone zone;

  @override
  Widget build(BuildContext context) {
    final style = DojiType.data.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Semantics(
          container: true,
          header: true,
          label: 'doji brief',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  const TextSpan(
                    text: '> ',
                    style: TextStyle(color: DojiColors.dojiGreen),
                  ),
                  const TextSpan(text: 'doji brief'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: BlinkingCursor(style: style),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (updatedAt != null)
          Semantics(
            container: true,
            child: Text('UPDATED ${clockTime(zone, updatedAt!)}', style: DojiType.label),
          ),
      ],
    );
  }
}

/// 05 · check again, with "remind me".
class _CheckAgainCard extends StatelessWidget {
  const _CheckAgainCard({required this.check, required this.zone, required this.set, required this.onRemind});

  final CheckAgain check;
  final UserZone zone;

  /// A reminder for this time is already set.
  final bool set;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final time = clockDayTime(zone, check.at, now: clock.now());
    final info = Semantics(
      container: true,
      label: 'check again at $time, ${check.why}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('05 · CHECK AGAIN', style: DojiType.label.copyWith(fontWeight: FontWeight.w400)),
            const SizedBox(height: 4),
            Text(time, style: DojiType.data),
            const SizedBox(height: 4),
            Text(check.why, style: DojiType.callout),
          ],
        ),
      ),
    );
    final button = DojiButton(
      label: set ? 'reminder set' : 'remind me',
      semanticLabel: set ? 'reminder set for $time' : 'remind me at $time',
      icon: Icon(set ? Icons.check_rounded : Icons.notifications_none_rounded),
      variant: DojiButtonVariant.secondary,
      size: DojiButtonSize.small,
      expand: false,
      onPressed: set ? null : onRemind,
    );
    // Side by side as drawn; stacked once large text leaves no room.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 12), button],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                button,
              ],
            ),
    );
  }
}

/// In place of 05 when the plan is done for today (max trades or the loss limit).
class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.dayDone});

  final bool dayDone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('05 · CHECK AGAIN', style: DojiType.label.copyWith(fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        Text('tomorrow', style: DojiType.data),
        const SizedBox(height: 4),
        Text(dayDone ? 'your plan is done for today' : 'when the market opens', style: DojiType.callout),
      ],
    ),
  );
}

/// Free plan, today's brief used on another instrument: the written sections
/// are locked; the conditions and the chart still show.
class _LockedBrief extends StatelessWidget {
  const _LockedBrief({required this.usedOn, required this.onUnlock});

  final String? usedOn;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final on = usedOn == null ? '' : ' on ${displaySymbol(usedOn!)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: DojiColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text('AI BRIEF · 1/1 USED TODAY', style: DojiType.label)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "you've used today's ai brief$on. the next one unlocks at 00:00. your conditions below are "
            'still measured.',
            style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
          ),
          const SizedBox(height: 4),
          DojiButton(
            label: 'see basic',
            variant: DojiButtonVariant.ghost,
            size: DojiButtonSize.small,
            expand: false,
            onPressed: onUnlock,
          ),
        ],
      ),
    );
  }
}

/// Doji Core Tabs › 01b "feed error": in place of the chart.
class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 200),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const TerminalLine('price feed not responding.', tone: TerminalTone.tilt),
        const SizedBox(height: 12),
        DojiButton(
          label: 'try again',
          variant: DojiButtonVariant.outline,
          size: DojiButtonSize.small,
          expand: false,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

/// Doji Core Tabs › 01b "market closed": over the dimmed chart.
class _ClosedTag extends StatelessWidget {
  const _ClosedTag({required this.opensAt, required this.zone, required this.now});

  final DateTime? opensAt;
  final UserZone zone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final at = opensAt;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: DojiColors.elevated2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(DojiRadius.chip),
          border: Border.all(color: DojiColors.separator),
        ),
        child: Text(
          at == null ? 'market closed' : 'market closed · opens ${clockDayTime(zone, at, now: now)}',
          style: DojiType.hint.copyWith(fontSize: 13, color: DojiColors.textPrimary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Doji Core Tabs › 01b "no strategy yet": in place of the written brief.
/// The rules below it are still measured.
/// TODO(next-slice): "build my strategy" once a strategy can be edited after
/// onboarding (the strategy editor is not built).
class _NoStrategyCard extends StatelessWidget {
  const _NoStrategyCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TerminalLine('no strategy yet.', tone: TerminalTone.primary, cursor: true, liveRegion: false),
        const SizedBox(height: 10),
        Text(
          'the brief measures this market against your strategy. describe it once, in your own words, and it '
          'fills in here. until then, doji checks your rules.',
          style: DojiType.callout,
        ),
      ],
    ),
  );
}

/// Tapping 1b's chart (or Enter on it) opens the full chart with the drawing
/// tools. Nothing is drawn at rest, so 1b looks the same; a focus outline
/// shows only while the keyboard is on it.
class _OpenChart extends StatefulWidget {
  const _OpenChart({required this.symbol, required this.child});

  final String symbol;
  final Widget child;

  @override
  State<_OpenChart> createState() => _OpenChartState();
}

class _OpenChartState extends State<_OpenChart> {
  bool _focused = false;

  void _open() => context.push(Routes.chart(widget.symbol));

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    button: true,
    label: 'open the full chart to draw',
    onTap: _open,
    child: FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open())},
      child: GestureDetector(
        onTap: _open,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: _focused ? Border.all(color: DojiColors.textPrimary, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}

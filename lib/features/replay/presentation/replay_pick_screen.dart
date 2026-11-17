import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../backtest/presentation/widgets/practice_widgets.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/presentation/pair_detail_controller.dart';

/// Pick an instrument and a past weekday to replay.
class ReplayPickScreen extends ConsumerStatefulWidget {
  const ReplayPickScreen({super.key});

  @override
  ConsumerState<ReplayPickScreen> createState() => _ReplayPickScreenState();
}

class _ReplayPickScreenState extends ConsumerState<ReplayPickScreen> {
  String? _symbol;

  static const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// The last [n] weekdays before today, newest first (UTC dates).
  static List<DateTime> pastWeekdays(DateTime now, {int n = 20}) {
    final out = <DateTime>[];
    var d = DateTime.utc(now.year, now.month, now.day);
    while (out.length < n) {
      d = d.subtract(const Duration(days: 1));
      if (d.weekday <= 5) out.add(d);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final instruments = [
      for (final s in ref.watch(marketsProfileProvider).instruments)
        if (instrumentBySymbol(s) != null) s,
    ];
    final symbol = _symbol ?? instruments.firstOrNull;
    return PracticeScaffold(
      title: 'replay',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.mePractice),
      children: [
        Text(
          'a past day bar by bar, from the tokyo open. the bars ahead stay hidden until you reveal them.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 16),
        if (instruments.isEmpty)
          const HintText('add instruments from markets first.')
        else ...[
          Text('instrument', style: DojiType.label),
          const SizedBox(height: 8),
          ChipRow<String>(
            values: instruments,
            selected: symbol,
            label: instrumentLabel,
            onTap: (s) => setState(() => _symbol = s),
          ),
          const SizedBox(height: 16),
          Text('day', style: DojiType.label),
          const SizedBox(height: 8),
          for (final d in pastWeekdays(clock.now().toUtc()))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DojiButton(
                label: '${_weekdays[d.weekday - 1]} ${fmtDate(d)}',
                semanticLabel: 'replay ${instrumentLabel(symbol!)} on ${fmtDate(d)}',
                variant: DojiButtonVariant.secondary,
                size: DojiButtonSize.regular,
                onPressed: () => context.push(Routes.replay(symbol, day: d)),
              ),
            ),
        ],
      ],
    );
  }
}

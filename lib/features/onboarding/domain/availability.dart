import 'onboarding_step.dart';

/// How often the trader can look at the charts during the hours they trade.
/// Stored on `ProfileDoji.availability` (one person, not per account).
/// Source: design/research-intake-plan.md › 1 (a strategy has to fit the trader's life).
const availabilityOptions = [
  StepOption('not_flexible', 'hardly at all', sub: 'busy job, meetings, offshore'),
  StepOption('semi_flexible', 'a few times a day', sub: '2–3 short checks'),
  StepOption('fully_flexible', 'whenever i want', sub: 'every hour if i like'),
];

/// Whether the trading style fits the trader's week. Measured from two answers, never a verdict
/// on the strategy itself.
typedef AvailabilityFit = ({bool fits, String line});

/// [availability] is an `availabilityOptions` value; [style] is `ProfileDoji.style`
/// (`scalper,day_trader`). Null when either is missing or the style is undecided.
AvailabilityFit? availabilityFit(String? availability, String? style) {
  final styles = (style ?? '').split(',').where((s) => s.isNotEmpty && s != 'undecided').toSet();
  if (availability == null || styles.isEmpty) return null;
  final needsScreen = styles.contains('scalper');
  final needsDay = needsScreen || styles.contains('day_trader');
  return switch (availability) {
    'not_flexible' when needsDay => (
      fits: false,
      line:
          "you can hardly look at the charts while you trade, and ${needsScreen ? 'scalping' : 'day trading'} "
          'needs you there. set entries as orders before work, or move to h4 and daily.',
    ),
    'semi_flexible' when needsScreen => (
      fits: false,
      line:
          "2–3 short checks a day don't cover scalping. day trades with orders set ahead, or h4, fit that week.",
    ),
    'not_flexible' ||
    'semi_flexible' ||
    'fully_flexible' => (fits: true, line: 'your style fits how often you can look at the charts.'),
    _ => null,
  };
}

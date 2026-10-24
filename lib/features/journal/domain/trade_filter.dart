import '../../markets/domain/time_zones.dart';
import '../../onboarding/domain/sessions.dart';
import 'formatting.dart';
import 'trade.dart';

/// What the trades list can be filtered by (Doji Trade Journal › filters).
enum FilterGroup {
  pair('pair', mono: true),
  setup('setup'),
  session('session'),
  weekday('weekday'),
  tag('mistake tag'),
  grade('process grade', mono: true),
  result('result');

  const FilterGroup(this.label, {this.mono = false});

  final String label;

  /// Values are symbols or letters: shown in Geist Mono.
  final bool mono;
}

const List<String> kSessionNames = ['sydney', 'tokyo', 'london', 'new york'];
const List<String> kOffHours = ['off hours'];
const List<String> kWeekdayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The session that opened most recently before [instant], within [window]
/// of its open; "off hours" when none did. Daylight saving moves the opens,
/// so the answer follows the calendar like `TradingSession` does.
String sessionOf(DateTime instant, {Duration window = const Duration(hours: 9)}) {
  String best = kOffHours.first;
  var bestElapsed = window.inMinutes;
  for (final s in const [
    TradingSession.sydney,
    TradingSession.tokyo,
    TradingSession.london,
    TradingSession.newYork,
  ]) {
    final location = TimeZones.find(s.zoneId!);
    if (location == null) continue;
    final local = TimeZones.inZone(instant, location);
    final minute = local.hour * 60 + local.minute;
    final elapsed = (minute - s.openLocalMinutes! + 24 * 60) % (24 * 60);
    if (elapsed < bestElapsed) {
      bestElapsed = elapsed;
      best = s.label.toLowerCase();
    }
  }
  return best;
}

/// A set of chosen values per [FilterGroup]. Empty group = no filter on it;
/// a trade must match every group that has a choice, and any one value in it.
class TradeFilter {
  const TradeFilter([this.selected = const {}]);

  final Map<FilterGroup, Set<String>> selected;

  Set<String> of(FilterGroup g) => selected[g] ?? const {};

  bool get isEmpty => selected.values.every((v) => v.isEmpty);

  /// Groups with at least one choice.
  int get activeGroups => selected.values.where((v) => v.isNotEmpty).length;

  TradeFilter toggled(FilterGroup g, String value) {
    final next = {
      for (final e in selected.entries) e.key: {...e.value},
    };
    final set = next.putIfAbsent(g, () => <String>{});
    if (!set.remove(value)) set.add(value);
    return TradeFilter(next);
  }

  static String resultOf(Trade t) => t.isWin ? 'win' : (t.isLoss ? 'loss' : 'flat');

  /// The value(s) a trade has for [g]; empty when it has none (unreviewed
  /// trades have no setup, tags or grade).
  static Iterable<String> valuesOf(Trade t, FilterGroup g) => switch (g) {
    FilterGroup.pair => [t.symbol],
    FilterGroup.setup => [if (t.setup != null) t.setup!],
    FilterGroup.session => [sessionOf(t.openedAt)],
    FilterGroup.weekday => [weekdayShort(t.openedAt.toLocal())],
    FilterGroup.tag => t.mistakes,
    FilterGroup.grade => [if (t.grade != null) t.grade!.letter],
    FilterGroup.result => [resultOf(t)],
  };

  bool matches(Trade t) {
    for (final e in selected.entries) {
      if (e.value.isEmpty) continue;
      if (!valuesOf(t, e.key).any(e.value.contains)) return false;
    }
    return true;
  }

  List<Trade> apply(Iterable<Trade> trades) => [
    for (final t in trades)
      if (matches(t)) t,
  ];

  /// "pair: XAUUSD", "setup: 2", for the chips above the list.
  String chipLabel(FilterGroup g) {
    final v = of(g);
    if (v.isEmpty) return g.label;
    return '${g.label.split(' ').last}: ${v.length == 1 ? v.first : v.length}';
  }
}

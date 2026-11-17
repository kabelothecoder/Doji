import '../../backtest/domain/backtest.dart';
import '../../backtest/domain/fills.dart';
import '../../chart/domain/bar_source.dart';
import '../../chart/domain/drawing.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/market_data.dart';

/// History fed to the chart bar by bar. [bars] never returns a bar past the
/// cursor: the future is not in the list the chart gets, so it cannot be
/// drawn, read out or measured.
class ReplayBarSource implements BarSource {
  ReplayBarSource(this._history, {required int cursor, required this.source})
    : cursor = cursor.clamp(0, _history.length);

  final List<Candle> _history;

  /// How many bars are shown: bars `[0, cursor)`.
  final int cursor;

  @override
  final FeedSource source;

  /// The bars shown, oldest first.
  List<Candle> get visible => _history.sublist(0, cursor);

  /// The last bar shown, if any.
  Candle? get last => cursor == 0 ? null : _history[cursor - 1];

  bool get atEnd => cursor >= _history.length;

  /// The last [count] bars shown up to [now]; [now] cannot reach past the cursor.
  @override
  Future<List<Candle>> bars(Timeframe tf, {required DateTime now, int count = 300}) async {
    final shown = [
      for (final c in visible)
        if (!c.at.isAfter(now)) c,
    ];
    return shown.length <= count ? shown : shown.sublist(shown.length - count);
  }
}

/// One position box in a replay, as doji follows it on the bars it reveals.
class PositionTrack {
  const PositionTrack({
    required this.id,
    required this.placedAfter,
    this.entryAt,
    this.entry,
    this.stopAtEntry,
    this.stop,
    this.target,
    this.stopMoved = false,
    this.exitAt,
    this.exit,
    this.reason = ExitReason.open,
  });

  final String id;

  /// Open time of the last bar shown when the box was placed. Only bars after
  /// it can fill the box: no fills on bars the trader already saw.
  final DateTime placedAfter;
  final DateTime? entryAt;
  final double? entry;
  final double? stopAtEntry;
  final double? stop;
  final double? target;
  final bool stopMoved;
  final DateTime? exitAt;
  final double? exit;
  final ExitReason reason;

  bool get entered => entryAt != null;
  bool get closed => reason != ExitReason.open;

  PositionTrack _copy({
    DateTime? entryAt,
    double? entry,
    double? stopAtEntry,
    double? stop,
    double? target,
    bool? stopMoved,
    DateTime? exitAt,
    double? exit,
    ExitReason? reason,
  }) => PositionTrack(
    id: id,
    placedAfter: placedAfter,
    entryAt: entryAt ?? this.entryAt,
    entry: entry ?? this.entry,
    stopAtEntry: stopAtEntry ?? this.stopAtEntry,
    stop: stop ?? this.stop,
    target: target ?? this.target,
    stopMoved: stopMoved ?? this.stopMoved,
    exitAt: exitAt ?? this.exitAt,
    exit: exit ?? this.exit,
    reason: reason ?? this.reason,
  );

  /// The box after [bar] is revealed, with [d] as the trader has it now (null
  /// once deleted). Entry when a bar at or after the box's time trades through
  /// its entry; from then on stops and targets follow [fillOn] (same bar =
  /// stop). A box removed before entry is dropped (null).
  PositionTrack? reveal(Candle bar, Drawing? d) {
    if (closed) return this;
    if (!bar.at.isAfter(placedAfter)) return this;
    if (d == null) {
      if (!entered) return null;
      return _copy(exitAt: bar.at, exit: bar.open, reason: ExitReason.closedByYou);
    }
    final stop = d.stop!, target = d.target!;
    if (!entered) {
      if (bar.at.isBefore(d.a.at) || bar.low > d.entry || bar.high < d.entry) {
        return _copy(stop: stop, target: target);
      }
      final from = Candle(at: bar.at, open: d.entry, high: bar.high, low: bar.low, close: bar.close);
      final t = _copy(entryAt: bar.at, entry: d.entry, stopAtEntry: stop, stop: stop, target: target);
      return t._fill(from, stop, target);
    }
    final moved = stopMoved || stop != stopAtEntry;
    return _copy(stop: stop, target: target, stopMoved: moved)._fill(bar, stop, target);
  }

  PositionTrack _fill(Candle bar, double stop, double target) {
    final f = fillOn(bar, stop: stop, target: target, stopBelow: stop < entry!);
    return f == null ? this : _copy(exitAt: bar.at, exit: f.price, reason: f.reason);
  }

  /// As a backtest trade (entered boxes only).
  BacktestTrade? toTrade(String symbol) => !entered
      ? null
      : BacktestTrade(
          symbol: symbol,
          session: sessionAt(entryAt!),
          entryAt: entryAt!,
          entry: entry!,
          stop: stopAtEntry!,
          target: target!,
          exitAt: exitAt,
          exit: exit,
          reason: reason,
        );
}

/// Every position box after [bar] is revealed. New boxes start being
/// followed from [lastShown] (the bar shown before [bar]).
Map<String, PositionTrack> revealBar(
  Map<String, PositionTrack> tracks,
  List<Drawing> drawings,
  Candle bar, {
  required DateTime lastShown,
}) {
  final boxes = {
    for (final d in drawings)
      if (d.kind == DrawingKind.position) d.id: d,
  };
  final out = <String, PositionTrack>{};
  for (final id in {...tracks.keys, ...boxes.keys}) {
    final t = tracks[id] ?? PositionTrack(id: id, placedAfter: lastShown);
    final next = t.reveal(bar, boxes[id]);
    if (next != null) out[id] = next;
  }
  return out;
}

import '../../markets/domain/market_format.dart';

/// The chart's drawing tools. [label] is what the toolbar, the list and the
/// screen reader say.
enum DrawingKind {
  zone('zone'),
  level('level'),
  trendLine('trend line'),
  position('position');

  const DrawingKind(this.label);

  final String label;
}

/// A point on the chart: a bar time (UTC) and a price. Drawings are anchored
/// to time and price, never to pixels, so they stay put across zoom,
/// timeframes and devices.
class ChartPoint {
  const ChartPoint(this.at, this.price);

  final DateTime at;
  final double price;

  ChartPoint shift(Duration dt, double dp) => ChartPoint(at.add(dt), price + dp);

  Map<String, Object?> toJson() => {'at': at.toUtc().toIso8601String(), 'price': price};

  static ChartPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    final price = json['price'];
    if (at == null || price is! num) return null;
    return ChartPoint(at.toUtc(), price.toDouble());
  }

  @override
  bool operator ==(Object other) => other is ChartPoint && other.at == at && other.price == price;

  @override
  int get hashCode => Object.hash(at, price);
}

/// Which part of a drawing a pointer or a key moves.
enum DrawingHandle { a, b, stop, target }

/// One mark the trader made.
///
/// - level: [a] (its time only says when it was drawn; the line is full width)
/// - zone: [a] and [b] are opposite corners
/// - trend line: from [a] to [b]
/// - position: [a] is the left edge at the entry price, [b] the right edge
///   (its price is the entry too), plus [stop] and [target]. It records the
///   trader's own plan; doji never proposes one.
class Drawing {
  const Drawing({required this.id, required this.kind, required this.a, this.b, this.stop, this.target});

  final String id;
  final DrawingKind kind;
  final ChartPoint a;
  final ChartPoint? b;
  final double? stop;
  final double? target;

  double get entry => a.price;

  /// The price levels the list and the screen reader read out, in order.
  List<(String, double)> get prices => switch (kind) {
    DrawingKind.level => [('price', a.price)],
    DrawingKind.zone => [('top', _max(a.price, b!.price)), ('bottom', _min(a.price, b!.price))],
    DrawingKind.trendLine => [('from', a.price), ('to', b!.price)],
    DrawingKind.position => [('entry', a.price), ('stop', stop!), ('target', target!)],
  };

  /// "stop below entry" / "stop above entry": the box never names a side with
  /// trade words (copy rules ban them), only where the trader put the stop.
  String? get stopSide =>
      kind != DrawingKind.position ? null : (stop! < entry ? 'stop below entry' : 'stop above entry');

  /// "level 1.08420", "zone 1.08300–1.08420".
  String describe(int decimals) {
    String p(double v) => formatPrice(v, decimals);
    return switch (kind) {
      DrawingKind.level => 'level ${p(a.price)}',
      DrawingKind.zone => 'zone ${p(_min(a.price, b!.price))}–${p(_max(a.price, b!.price))}',
      DrawingKind.trendLine => 'trend line ${p(a.price)} to ${p(b!.price)}',
      DrawingKind.position => 'position · entry ${p(entry)} · stop ${p(stop!)} · target ${p(target!)}',
    };
  }

  Drawing copyWith({ChartPoint? a, ChartPoint? b, double? stop, double? target}) => Drawing(
    id: id,
    kind: kind,
    a: a ?? this.a,
    b: b ?? this.b,
    stop: stop ?? this.stop,
    target: target ?? this.target,
  );

  /// The whole drawing moved by [dt] and [dp].
  Drawing shifted(Duration dt, double dp) => Drawing(
    id: id,
    kind: kind,
    a: a.shift(dt, dp),
    b: b?.shift(dt, dp),
    stop: stop == null ? null : stop! + dp,
    target: target == null ? null : target! + dp,
  );

  /// [handle] put at [p]. A position's left edge and right edge keep the
  /// entry on both; its stop and target only move in price.
  Drawing withHandle(DrawingHandle handle, ChartPoint p) => switch ((kind, handle)) {
    (DrawingKind.position, DrawingHandle.a) => copyWith(a: p, b: ChartPoint(b!.at, p.price)),
    (DrawingKind.position, DrawingHandle.b) => copyWith(b: ChartPoint(p.at, a.price)),
    (_, DrawingHandle.a) => copyWith(a: p),
    (_, DrawingHandle.b) => copyWith(b: p),
    (_, DrawingHandle.stop) => copyWith(stop: p.price),
    (_, DrawingHandle.target) => copyWith(target: p.price),
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'a': a.toJson(),
    if (b != null) 'b': b!.toJson(),
    'stop': ?stop,
    'target': ?target,
  };

  /// Null for a record that is not a whole drawing (skipped, never fatal).
  static Drawing? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = DrawingKind.values.asNameMap()[json['kind']];
    final id = json['id'];
    final a = ChartPoint.fromJson(json['a']);
    final b = ChartPoint.fromJson(json['b']);
    final stop = json['stop'], target = json['target'];
    if (kind == null || id is! String || a == null) return null;
    if (kind != DrawingKind.level && b == null) return null;
    if (kind == DrawingKind.position && (stop is! num || target is! num)) return null;
    return Drawing(
      id: id,
      kind: kind,
      a: a,
      b: b,
      stop: stop is num ? stop.toDouble() : null,
      target: target is num ? target.toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Drawing &&
      other.id == id &&
      other.kind == kind &&
      other.a == a &&
      other.b == b &&
      other.stop == stop &&
      other.target == target;

  @override
  int get hashCode => Object.hash(id, kind, a, b, stop, target);
}

double _min(double x, double y) => x < y ? x : y;
double _max(double x, double y) => x > y ? x : y;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/candle.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';

/// One open connection to Deriv's websocket. A seam so tests run without a network.
abstract interface class DerivSocket {
  /// Raw JSON frames from Deriv. Done (or an error) = the connection dropped.
  Stream<String> get messages;
  void send(String frame);
  Future<void> close();
}

typedef DerivConnector = Future<DerivSocket> Function();

/// Deriv's public options websocket (developers.deriv.com › WebSocket public):
/// market data needs no account and no auth. [appId] is optional: the docs
/// only require `Deriv-App-ID` for REST and PAT apps; it is sent as `app_id`
/// when set (`--dart-define=DERIV_APP_ID=…` or assets/env/.env).
Uri derivPublicUri({String appId = ''}) => Uri.parse(
  'wss://api.derivws.com/trading/v1/options/ws/public${appId.isEmpty ? '' : '?app_id=${Uri.encodeQueryComponent(appId)}'}',
);

/// Opens a real socket.
DerivConnector derivConnector({String appId = ''}) => () async {
  final channel = WebSocketChannel.connect(derivPublicUri(appId: appId));
  await channel.ready;
  return _ChannelSocket(channel);
};

class _ChannelSocket implements DerivSocket {
  _ChannelSocket(this._c);

  final WebSocketChannel _c;

  @override
  Stream<String> get messages => _c.stream.map((m) => m is String ? m : utf8.decode(m as List<int>));

  @override
  void send(String frame) => _c.sink.add(frame);

  @override
  Future<void> close() => _c.sink.close();
}

/// Real prices for Deriv synthetics (Volatility, Boom, Crash) from
/// `ticks_history` (style `candles` for bars, `ticks` for the last price).
///
/// One socket, shared by every request, kept alive with `ping`. When it drops,
/// every pending request fails with [FeedUnavailable] (1b shows "price feed not
/// responding.") and doji reconnects with backoff: 1s, 2s, 4s … up to 30s.
/// Until then requests fail at once instead of piling up.
class DerivMarketData implements MarketData {
  DerivMarketData({
    required DerivConnector connect,
    this.timeout = const Duration(seconds: 10),
    this.pingEvery = const Duration(seconds: 30),
  }) : _connect = connect;

  final DerivConnector _connect;
  final Duration timeout;
  final Duration pingEvery;

  static const maxBackoff = Duration(seconds: 30);

  DerivSocket? _socket;
  Future<DerivSocket>? _connecting;
  StreamSubscription<String>? _sub;
  Timer? _ping;
  Timer? _retry;
  DateTime? _retryAt;
  int _failures = 0;
  int _nextId = 1;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  bool _disposed = false;

  /// True while doji is waiting to reconnect.
  bool get reconnecting => _retryAt != null;

  /// Wait before the [n]th reconnect (1-based): 1s, 2s, 4s … capped at 30s.
  static Duration backoff(int n) =>
      Duration(milliseconds: math.min(maxBackoff.inMilliseconds, 1000 * (1 << (math.min(n, 16) - 1))));

  @override
  FeedSource sourceOf(String symbol) => const FeedSource.live('deriv');

  Future<DerivSocket> _ensure() {
    final open = _socket;
    if (open != null) return Future.value(open);
    if (_disposed) return Future.error(const FeedUnavailable('closed'));
    final retryAt = _retryAt;
    if (retryAt != null && clock.now().isBefore(retryAt)) {
      return Future.error(const FeedUnavailable('reconnecting'));
    }
    return _connecting ??= _open();
  }

  Future<DerivSocket> _open() async {
    try {
      final s = await _connect().timeout(timeout);
      _socket = s;
      _failures = 0;
      _retryAt = null;
      _sub = s.messages.listen(_onFrame, onError: (_) => _drop(), onDone: _drop);
      _ping = Timer.periodic(pingEvery, (_) => s.send(jsonEncode({'ping': 1})));
      return s;
    } on Object catch (e) {
      _scheduleRetry();
      throw FeedUnavailable('connect failed: $e');
    } finally {
      _connecting = null;
    }
  }

  void _onFrame(String frame) {
    final Object? msg;
    try {
      msg = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (msg is! Map<String, dynamic>) return;
    final id = msg['req_id'];
    final c = id is int ? _pending.remove(id) : null;
    if (c == null) return;
    final error = msg['error'];
    if (error is Map) {
      c.completeError(FeedUnavailable('${error['code']}: ${error['message']}'));
    } else {
      c.complete(msg);
    }
  }

  void _drop() {
    _sub?.cancel();
    _ping?.cancel();
    _sub = null;
    _ping = null;
    _socket = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const FeedUnavailable('connection dropped'));
    }
    _pending.clear();
    if (!_disposed) _scheduleRetry();
  }

  void _scheduleRetry() {
    _failures++;
    final wait = backoff(_failures);
    _retryAt = clock.now().add(wait);
    _retry?.cancel();
    // Reconnect on its own, so the next request finds the socket open.
    _retry = Timer(wait, () {
      _retryAt = null;
      if (!_disposed && _socket == null) _ensure().ignore();
    });
  }

  Future<Map<String, dynamic>> _request(Map<String, Object?> body) async {
    final s = await _ensure();
    final id = _nextId++;
    final c = _pending[id] = Completer<Map<String, dynamic>>();
    s.send(jsonEncode({...body, 'req_id': id}));
    try {
      return await c.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      throw const FeedUnavailable('no answer');
    }
  }

  static int _epoch(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;

  static List<Candle> _candles(Map<String, dynamic> msg) => [
    for (final c in (msg['candles'] as List? ?? const []).whereType<Map<String, dynamic>>())
      Candle(
        at: DateTime.fromMillisecondsSinceEpoch((c['epoch'] as num).toInt() * 1000, isUtc: true),
        open: (c['open'] as num).toDouble(),
        high: (c['high'] as num).toDouble(),
        low: (c['low'] as num).toDouble(),
        close: (c['close'] as num).toDouble(),
      ),
  ];

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return null;
    final results = await Future.wait([
      _request({'ticks_history': instrument.symbol, 'end': 'latest', 'count': 1, 'style': 'ticks'}),
      _request({
        'ticks_history': instrument.symbol,
        'end': 'latest',
        'count': 1,
        'style': 'candles',
        'granularity': 86400,
      }),
    ]);
    final history = results[0]['history'] as Map?;
    final prices = history?['prices'] as List?;
    final times = history?['times'] as List?;
    if (prices == null || prices.isEmpty || times == null || times.isEmpty) return null;
    final price = (prices.last as num).toDouble();
    final day = _candles(results[1]);
    final pip = results[0]['pip_size'];
    return Quote(
      symbol: instrument.symbol,
      price: price,
      dayOpen: day.isEmpty ? price : day.last.open,
      at: DateTime.fromMillisecondsSinceEpoch((times.last as num).toInt() * 1000, isUtc: true),
      decimals: pip is num ? pip.toInt() : 2,
      marketOpen: instrument.hours.isOpenAt(now.toUtc()),
    );
  }

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return const [];
    return _candles(
      await _request({
        'ticks_history': instrument.symbol,
        'end': '${_epoch(now)}',
        'count': count,
        'style': 'candles',
        'granularity': tf.duration.inSeconds,
      }),
    );
  }

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return const [];
    return _candles(
      await _request({
        'ticks_history': instrument.symbol,
        'start': _epoch(from),
        'end': '${_epoch(to)}',
        'count': 5000,
        'style': 'candles',
        'granularity': tf.duration.inSeconds,
      }),
    );
  }

  /// Closes the socket and stops reconnecting.
  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    final s = _socket;
    _drop();
    await s?.close();
  }
}

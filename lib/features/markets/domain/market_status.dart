import '../../onboarding/domain/sessions.dart';
import 'instrument.dart';

/// What 1b's session chip says about an instrument right now.
sealed class MarketStatus {
  const MarketStatus();

  /// Never closes (crypto, synthetic indices).
  const factory MarketStatus.always() = AlwaysOpen;

  /// Open, inside [session], which closes at [closesAt].
  const factory MarketStatus.inSession(TradingSession session, DateTime closesAt) = InSession;

  /// Open between the named sessions.
  const factory MarketStatus.open() = OpenBetweenSessions;

  /// Closed until [opensAt] (null: not within the next week).
  const factory MarketStatus.closed(DateTime? opensAt) = MarketClosed;

  bool get isOpen => this is! MarketClosed;

  /// Where [instrument] is at [now]. Unknown (custom) symbols count as open:
  /// doji would rather not say a false "closed".
  static MarketStatus of(Instrument? instrument, DateTime now) {
    final hours = instrument?.hours;
    if (hours == null) return const MarketStatus.open();
    if (hours.alwaysOpen) return const MarketStatus.always();
    final t = now.toUtc();
    if (!hours.isOpenAt(t)) return MarketStatus.closed(hours.nextOpenAfter(t));
    // The session that opened most recently is the one the market is "in".
    TradingSession? latest;
    DateTime? latestOpen;
    for (final s in TradingSession.fixed) {
      if (!s.isOpenAt(t)) continue;
      final open = s.openInstant(t)!;
      if (latestOpen == null || open.isAfter(latestOpen)) {
        latest = s;
        latestOpen = open;
      }
    }
    return latest == null
        ? const MarketStatus.open()
        : MarketStatus.inSession(latest, latest.closeInstant(t)!);
  }
}

class AlwaysOpen extends MarketStatus {
  const AlwaysOpen();
}

class InSession extends MarketStatus {
  const InSession(this.session, this.closesAt);
  final TradingSession session;
  final DateTime closesAt;
}

class OpenBetweenSessions extends MarketStatus {
  const OpenBetweenSessions();
}

class MarketClosed extends MarketStatus {
  const MarketClosed(this.opensAt);
  final DateTime? opensAt;
}

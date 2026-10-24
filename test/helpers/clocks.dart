import 'package:clock/clock.dart';

/// Fixed days for anything that follows daylight saving. Wrap a test body in
/// `withClock(summerDay, ...)` so it gives the same answer all year.
///
/// Summer: London is on BST (UTC+1), New York on EDT (UTC-4), Sydney on AEST
/// (UTC+10). Winter: GMT, EST (UTC-5), AEDT (UTC+11).
final Clock summerDay = Clock.fixed(DateTime.utc(2026, 7, 15, 12));
final Clock winterDay = Clock.fixed(DateTime.utc(2026, 12, 15, 12));

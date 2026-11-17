import '../../onboarding/domain/sessions.dart';
import 'instrument.dart';
import 'instrument_catalog.dart';
import 'time_zones.dart';

/// 'EUR/USD' for six-letter pairs and metals, the chip label otherwise
/// ('Volatility 75', 'NAS100').
String displaySymbol(String symbol) {
  final i = instrumentBySymbol(symbol);
  final pairish = i != null && (i.assetClass == AssetClass.forex || i.group == InstrumentGroup.metals);
  if (pairish && i.label == null && i.symbol.length == 6) {
    return '${i.symbol.substring(0, 3)}/${i.symbol.substring(3)}';
  }
  return instrumentLabel(symbol);
}

/// '1.08420', '20,512.40': fixed places, thousands grouped.
String formatPrice(double v, int decimals) {
  final fixed = v.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final frac = dot < 0 ? '' : fixed.substring(dot);
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) b.write(',');
    b.write(whole[i]);
  }
  return '$b$frac';
}

/// '+0.12%', '-0.08%', '0.00%'.
String formatChange(double pct) {
  final r = double.parse(pct.toStringAsFixed(2));
  if (r == 0) return '0.00%';
  return '${r > 0 ? '+' : '-'}${r.abs().toStringAsFixed(2)}%';
}

/// A price distance in the trader's units: '32-pip' for forex, '12.40-point'
/// otherwise (for "a 32-pip range").
String distanceLabel(Instrument? instrument, double distance, {required int decimals}) {
  final tick = instrument?.tickSize;
  if (instrument?.assetClass == AssetClass.forex && tick != null) {
    final pips = (distance / (tick * 10)).round();
    return '$pips-pip';
  }
  return '${formatPrice(distance, decimals > 2 ? 2 : decimals)}-point';
}

/// Wall-clock fields of [instant] on the trader's clock (as a UTC DateTime).
DateTime onClock(UserZone zone, DateTime instant) =>
    instant.toUtc().add(Duration(minutes: zone.offsetMinutesAt(instant)));

/// '14:30' on the trader's clock.
String clockTime(UserZone zone, DateTime instant) => hhmm(zone.minuteOfDayAt(instant));

const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// '14:30' today, 'tomorrow 02:00', else 'sun 23:00', on the trader's clock.
String clockDayTime(UserZone zone, DateTime instant, {required DateTime now}) {
  final at = onClock(zone, instant), today = onClock(zone, now);
  final days = DateTime.utc(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final time = clockTime(zone, instant);
  if (days == 0) return time;
  if (days == 1) return 'tomorrow $time';
  return '${_weekdays[at.weekday - 1]} $time';
}

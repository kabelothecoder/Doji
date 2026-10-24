import 'journal_stats.dart';
import 'trade.dart';

const String _minus = '−';

/// "1,234.50". Two decimals, thousands separated, no sign.
String groupedAmount(double v, {int decimals = 2}) {
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}

/// "+$120.00" / "−$45.50". Zero reads "$0.00".
String formatMoney(double v, String symbol, {bool signed = true}) {
  final body = '$symbol${groupedAmount(v)}';
  if (!signed || v.abs() < 0.005) return body;
  return '${v > 0 ? '+' : _minus}$body';
}

/// "+1.8R" / "−0.9R".
String formatR(double v, {bool signed = true}) {
  final body = '${v.abs().toStringAsFixed(1)}R';
  if (!signed || v.abs() < 0.05) return body;
  return '${v > 0 ? '+' : _minus}$body';
}

/// [value] in the unit the trader picked.
String formatValue(double value, ResultUnit unit, String symbol, {bool signed = true}) =>
    unit == ResultUnit.r ? formatR(value, signed: signed) : formatMoney(value, symbol, signed: signed);

/// A trade's result in [unit]; falls back to money when the trade has no R.
String tradeResult(Trade t, ResultUnit unit, String symbol) {
  final r = t.r;
  if (unit == ResultUnit.r && r != null) return formatR(r);
  return formatMoney(t.pnl, symbol);
}

/// A price with the places the instrument quotes.
String formatPrice(double v, int decimals) => v.toStringAsFixed(decimals);

const List<String> _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

String weekdayShort(DateTime local) => _weekdays[local.weekday - 1];
String monthShort(int month) => _months[month - 1];

String _two(int n) => n.toString().padLeft(2, '0');

/// "08 oct".
String dayLabel(DateTime local) => '${_two(local.day)} ${monthShort(local.month)}';

/// "15:40".
String clockLabel(DateTime local) => '${_two(local.hour)}:${_two(local.minute)}';

/// "08 oct · 15:40", on the trader's own clock.
String whenLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${dayLabel(local)} · ${clockLabel(local)}';
}

/// "42 min", "2h 05m".
String durationLabel(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}h ${_two(minutes % 60)}m';
}

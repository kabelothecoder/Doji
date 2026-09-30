/// Above this, risk per trade gets a calm tilt-orange note — never a block.
const double riskNoteThreshold = 2.0;

/// "3" for 3.0, "2.5" for 2.5, "0.5" for 0.5.
String fmtPct(double v) {
  final rounded = (v * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toString().replaceFirst(RegExp(r'0+$'), '');
}

/// Handoff 4c copy, with the numbers computed from [riskPct].
/// Returns null at or below [riskNoteThreshold].
String? riskNote(double? riskPct) {
  if (riskPct == null || riskPct <= riskNoteThreshold) return null;
  final r = fmtPct(riskPct);
  final three = fmtPct(riskPct * 3);
  return '$r% is above what most plans allow. three losses in a row is about $three% down. '
      "you can keep it; i'll remind you before sessions.";
}

import 'dart:math' as math;

/// Formats a linear level (1.0 = 0 dB) as dB with one decimal, e.g. "−6.0 dB".
/// Level 0 (or less) is silence: "−∞ dB".
String formatLevelDb(double level) {
  if (level <= 0) return '−∞ dB';
  final db = 20 * math.log(level) / math.ln10;
  final text = db.abs().toStringAsFixed(1);
  if (text == '0.0') return '0.0 dB';
  return '${db < 0 ? '−' : '+'}$text dB';
}

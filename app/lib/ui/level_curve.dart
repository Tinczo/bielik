import 'dart:math' as math;

/// The slider's curve: maps a slider position (0..1) to a linear level
/// (1.0 = 0 dB) and back. Only the app knows it; the wire carries levels.
///
/// The level grows with the cube of the position, like an audio-taper fader:
/// the far left end is silence (−∞ dB), the far right end is [maxLevel]
/// (+12 dB, as REAPER's faders), and 0 dB sits at about 63% of the way.
const double maxLevel = 3.981071705534973; // +12 dB

double levelFromPosition(double position) {
  final p = position.clamp(0.0, 1.0);
  return maxLevel * p * p * p;
}

/// Levels above [maxLevel] (possible when set in REAPER) show at the far right.
double positionFromLevel(double level) {
  if (level <= 0) return 0;
  final p = math.pow(level / maxLevel, 1 / 3).toDouble();
  return p.clamp(0.0, 1.0);
}

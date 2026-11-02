import 'package:bielik/ui/level_curve.dart';
import 'package:bielik/ui/level_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the far left end of the slider is silence', () {
    expect(levelFromPosition(0), 0);
    expect(formatLevelDb(levelFromPosition(0)), '−∞ dB');
  });

  test('the far right end of the slider is +12 dB', () {
    expect(formatLevelDb(levelFromPosition(1)), '+12.0 dB');
  });

  test('a level maps to a slider position and back', () {
    for (final level in [0.001, 0.25, 0.5, 1.0, 2.0, 3.9]) {
      expect(levelFromPosition(positionFromLevel(level)), closeTo(level, 1e-9));
    }
  });

  test('levels above +12 dB show at the far right end', () {
    expect(positionFromLevel(8.0), 1.0);
  });

  test('0 dB sits right of the middle, leaving room to turn things down', () {
    final zeroDb = positionFromLevel(1.0);
    expect(zeroDb, greaterThan(0.5));
    expect(zeroDb, lessThan(0.75));
  });
}

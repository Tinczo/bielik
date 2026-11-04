import 'package:flutter_test/flutter_test.dart';

/// Widget tests run in fake time, but the fake server talks over real sockets.
/// Lets real time pass (so socket I/O completes) and pumps frames until
/// [finder] matches something, or fails after [timeout].
///
/// Each frame also moves fake time on by [advance], so the app's own timers
/// (e.g. the reconnect backoff) run too.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration advance = Duration.zero,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(advance);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $finder');
}

/// Like [pumpUntilFound], but waits until [condition] holds.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String description = 'condition',
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (condition()) return;
  }
  fail('timed out waiting for $description');
}

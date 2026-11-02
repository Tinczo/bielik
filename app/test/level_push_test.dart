import 'package:bielik/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

// From protocol/examples/level-push.json.
const _guitarId = '{1B6A2C10-0002-4A3E-9C1D-000000000002}';

Finder _sliderOf(String sourceId) => find.byKey(Key('level-$sourceId'));

Finder _rowOf(String name) => find.ancestor(
  of: find.descendant(
    of: find.byKey(const Key('sources')),
    matching: find.text(name),
  ),
  matching: find.byType(ListTile),
);

Finder _levelIn(String row, String level) =>
    find.descendant(of: _rowOf(row), matching: find.text(level));

/// Connects to a fake server playing level-push.json and opens the "Wokal"
/// monitor: Gitara at −6.0 dB, Wokal at 0.0 dB.
Future<FakeMixerServer> _openMonitor(WidgetTester tester) async {
  final server = (await tester.runAsync(
    () => FakeMixerServer.start(loadProtocolExample('level-push.json')),
  ))!;
  addTearDown(() => tester.runAsync(server.close));

  await tester.pumpWidget(BielikApp(passwordStore: InMemoryPasswordStore()));
  await tester.enterText(find.byKey(const Key('host')), server.host);
  await tester.enterText(find.byKey(const Key('port')), '${server.port}');
  await tester.tap(find.text('Połącz'));
  await pumpUntilFound(tester, find.text('Wokal'));
  await tester.tap(find.text('Wokal'));
  await pumpUntilFound(tester, _sliderOf(_guitarId));
  return server;
}

void main() {
  testWidgets('levels changed in REAPER move the sliders by themselves', (
    tester,
  ) async {
    final server = await _openMonitor(tester);
    expect(_levelIn('Gitara', '−6.0 dB'), findsOneWidget);
    expect(_levelIn('Wokal', '0.0 dB'), findsOneWidget);

    server.changeProject();
    await pumpUntilFound(tester, _levelIn('Wokal', '−6.0 dB'));
    expect(_levelIn('Gitara', '0.0 dB'), findsOneWidget);

    server.changeProject();
    await pumpUntilFound(tester, _levelIn('Gitara', '−12.0 dB'));
    expect(server.problems, isEmpty);
  });

  testWidgets(
    'a slider held by the musician ignores pushed levels and shows the '
    "server's state after release",
    (tester) async {
      final server = await _openMonitor(tester);
      final slider = _sliderOf(_guitarId);

      final finger = await tester.startGesture(tester.getCenter(slider));
      await finger.moveBy(const Offset(-30, 0));
      await tester.pump();
      final heldLevel = tester
          .widget<Text>(
            find.descendant(
              of: _rowOf('Gitara'),
              matching: find.textContaining('dB'),
            ),
          )
          .data;

      // The push changes both sources; only the untouched one follows it.
      server.changeProject();
      await pumpUntilFound(tester, _levelIn('Wokal', '−6.0 dB'));
      expect(_levelIn('Gitara', heldLevel!), findsOneWidget);
      expect(_levelIn('Gitara', '0.0 dB'), findsNothing);

      await finger.up();
      await tester.pump();
      server.changeProject();
      await pumpUntilFound(tester, _levelIn('Gitara', '−12.0 dB'));
      expect(server.problems, isEmpty);
      await tester.pump(kDoubleTapTimeout); // let the double-tap timer expire
    },
  );
}

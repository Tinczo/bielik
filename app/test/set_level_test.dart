import 'package:bielik/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

// From protocol/examples/subscribe.json.
const _monitorId = '{1B6A2C10-0010-4A3E-9C1D-000000000010}';
const _guitarId = '{1B6A2C10-0002-4A3E-9C1D-000000000002}';

Finder _sliderOf(String sourceId) => find.byKey(Key('level-$sourceId'));

Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ListTile));

/// Connects to a fake server playing subscribe.json and opens the "Wokal" monitor.
Future<FakeMixerServer> _openMonitor(WidgetTester tester) async {
  final server = (await tester.runAsync(
    () => FakeMixerServer.start(loadProtocolExample('subscribe.json')),
  ))!;
  addTearDown(() => tester.runAsync(server.close));

  await tester.pumpWidget(const BielikApp());
  await tester.enterText(find.byKey(const Key('host')), server.host);
  await tester.enterText(find.byKey(const Key('port')), '${server.port}');
  await tester.tap(find.text('Połącz'));
  await pumpUntilFound(tester, find.text('Wokal'));
  await tester.tap(find.text('Wokal'));
  await pumpUntilFound(tester, _sliderOf(_guitarId));
  return server;
}

List<Map<String, dynamic>> _setLevels(FakeMixerServer server) => server
    .extraMessages
    .where((message) => message['type'] == 'set_level')
    .toList();

void main() {
  testWidgets('double tap on a source slider resets it to 0 dB', (
    tester,
  ) async {
    final server = await _openMonitor(tester);
    final guitar = _rowOf('Gitara');
    expect(
      find.descendant(of: guitar, matching: find.text('−6.0 dB')),
      findsOneWidget,
    );

    await tester.tap(_sliderOf(_guitarId));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_sliderOf(_guitarId));
    await tester.pump(kDoubleTapTimeout);
    await pumpUntil(
      tester,
      () => _setLevels(server).isNotEmpty,
      description: 'set_level',
    );

    expect(_setLevels(server), [
      {
        'type': 'set_level',
        'monitorId': _monitorId,
        'sourceId': _guitarId,
        'level': 1.0,
      },
    ]);
    expect(
      find.descendant(of: guitar, matching: find.text('0.0 dB')),
      findsOneWidget,
    );
    expect(server.problems, isEmpty);
  });

  testWidgets(
    'dragging a slider to the far left sends live levels at a limited rate '
    'and silences the source on release',
    (tester) async {
      final server = await _openMonitor(tester);
      final slider = _sliderOf(_guitarId);

      // Over a hundred pointer moves within half a second.
      await tester.timedDrag(
        slider,
        Offset(-tester.getSize(slider).width, 0),
        const Duration(milliseconds: 500),
        frequency: 240,
      );
      await pumpUntil(
        tester,
        () => _setLevels(server).any((message) => message['level'] == 0),
        description: 'set_level with level 0',
      );

      final levels = [
        for (final message in _setLevels(server)) message['level'] as num,
      ];
      // Live during the gesture, but not one message per pointer move:
      // at most ~25 per second plus the final value.
      expect(levels.length, greaterThan(3));
      expect(levels.length, lessThanOrEqualTo(15));
      expect(levels.last, 0);
      for (final message in _setLevels(server)) {
        expect(message['monitorId'], _monitorId);
        expect(message['sourceId'], _guitarId);
      }
      expect(
        find.descendant(of: _rowOf('Gitara'), matching: find.text('−∞ dB')),
        findsOneWidget,
      );
      expect(server.problems, isEmpty);
    },
  );
}

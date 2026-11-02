import 'package:bielik/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

// From protocol/examples/subscribe.json: Gitara at 0.5 (−6.0 dB),
// Wokal at 1.0 (0.0 dB) in the "Wokal" monitor.
const _monitorId = '{1B6A2C10-0010-4A3E-9C1D-000000000010}';
const _guitarId = '{1B6A2C10-0002-4A3E-9C1D-000000000002}';
const _vocalId = '{1B6A2C10-0001-4A3E-9C1D-000000000001}';

final _undo = find.byKey(const Key('undo'));
final _redo = find.byKey(const Key('redo'));

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

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<IconButton>(button).onPressed != null;

/// subscribe.json's monitor, then (after [FakeMixerServer.changeProject])
/// Gitara removed from it in REAPER.
ProtocolExample _guitarRemoved() {
  final steps = loadProtocolExample('subscribe.json').steps;
  final monitor = steps.last['server'] as Map<String, dynamic>;
  return ProtocolExample('guitar-removed', {
    'steps': [
      ...steps,
      {'project': <String, dynamic>{}},
      {
        'server': {
          ...monitor,
          'sources': [
            for (final source in monitor['sources'] as List)
              if ((source as Map)['id'] != _guitarId) source,
          ],
        },
      },
    ],
  });
}

Future<FakeMixerServer> _startServer(
  WidgetTester tester, [
  Object example = 'subscribe.json',
]) async {
  final server = (await tester.runAsync(
    () => FakeMixerServer.start(
      example is ProtocolExample
          ? example
          : loadProtocolExample(example as String),
    ),
  ))!;
  addTearDown(() => tester.runAsync(server.close));
  return server;
}

/// Connects to [server] and opens the "Wokal" monitor.
Future<void> _openMonitor(WidgetTester tester, FakeMixerServer server) async {
  await tester.enterText(find.byKey(const Key('host')), server.host);
  await tester.enterText(find.byKey(const Key('port')), '${server.port}');
  await tester.tap(find.text('Połącz'));
  await pumpUntilFound(tester, find.text('Wokal'));
  await tester.tap(find.text('Wokal'));
  await pumpUntilFound(tester, _sliderOf(_guitarId));
}

Future<FakeMixerServer> _startAndOpen(
  WidgetTester tester, [
  Object example = 'subscribe.json',
]) async {
  final server = await _startServer(tester, example);
  await tester.pumpWidget(BielikApp(passwordStore: InMemoryPasswordStore()));
  await _openMonitor(tester, server);
  return server;
}

/// Drags the slider of [sourceId] all the way to the left (−∞) and, unless
/// told otherwise, waits until the server got the final level.
Future<void> _silence(
  WidgetTester tester,
  FakeMixerServer server,
  String sourceId, {
  bool waitForServer = true,
}) async {
  final slider = _sliderOf(sourceId);
  await tester.drag(slider, Offset(-tester.getSize(slider).width, 0));
  await tester.pump(kDoubleTapTimeout);
  if (waitForServer) await _waitForLevel(tester, server, sourceId, 0.0);
}

/// Double taps the slider of [sourceId] (reset to 0 dB) and waits until the
/// server got it.
Future<void> _reset(
  WidgetTester tester,
  FakeMixerServer server,
  String sourceId,
) async {
  await tester.tap(_sliderOf(sourceId));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(_sliderOf(sourceId));
  await tester.pump(kDoubleTapTimeout);
  await _waitForLevel(tester, server, sourceId, 1.0);
}

Future<void> _waitForLevel(
  WidgetTester tester,
  FakeMixerServer server,
  String sourceId,
  double level,
) => pumpUntil(tester, () {
  final last = _setLevels(server).lastOrNull;
  return last?['sourceId'] == sourceId && last?['level'] == level;
}, description: 'set_level $level for $sourceId');

List<Map<String, dynamic>> _setLevels(FakeMixerServer server) => server
    .extraMessages
    .where((message) => message['type'] == 'set_level')
    .toList();

/// The set_level message for [sourceId] in the test's monitor.
Map<String, Object> _setLevel(String sourceId, double level) => {
  'type': 'set_level',
  'monitorId': _monitorId,
  'sourceId': sourceId,
  'level': level,
};

/// Taps [button] and waits until the server got a set_level for it.
Future<Map<String, dynamic>> _press(
  WidgetTester tester,
  FakeMixerServer server,
  Finder button,
) async {
  final before = _setLevels(server).length;
  await tester.tap(button);
  await pumpUntil(
    tester,
    () => _setLevels(server).length > before,
    description: 'set_level after tapping $button',
  );
  return _setLevels(server).last;
}

void main() {
  testWidgets('undo puts back the level from before the drag, redo the level '
      'after it', (tester) async {
    final server = await _startAndOpen(tester);
    await _silence(tester, server, _guitarId);
    expect(_levelIn('Gitara', '−∞ dB'), findsOneWidget);

    expect(await _press(tester, server, _undo), _setLevel(_guitarId, 0.5));
    expect(_levelIn('Gitara', '−6.0 dB'), findsOneWidget);

    expect(await _press(tester, server, _redo), _setLevel(_guitarId, 0.0));
    expect(_levelIn('Gitara', '−∞ dB'), findsOneWidget);
    expect(server.problems, isEmpty);
  });

  testWidgets('each gesture is one step, a reset to 0 dB too; undo goes back '
      'step by step and a new gesture clears redo', (tester) async {
    final server = await _startAndOpen(tester);
    expect(_enabled(tester, _undo), isFalse);
    expect(_enabled(tester, _redo), isFalse);

    await _reset(tester, server, _guitarId); // 0.5 -> 1.0
    await _silence(tester, server, _vocalId); // 1.0 -> 0.0
    await _silence(tester, server, _guitarId); // 1.0 -> 0.0
    expect(_enabled(tester, _undo), isTrue);
    expect(_enabled(tester, _redo), isFalse);

    expect(await _press(tester, server, _undo), _setLevel(_guitarId, 1.0));
    expect(await _press(tester, server, _undo), _setLevel(_vocalId, 1.0));
    expect(await _press(tester, server, _undo), _setLevel(_guitarId, 0.5));
    expect(_enabled(tester, _undo), isFalse);
    expect(_enabled(tester, _redo), isTrue);
    expect(_levelIn('Gitara', '−6.0 dB'), findsOneWidget);
    expect(_levelIn('Wokal', '0.0 dB'), findsOneWidget);

    expect(await _press(tester, server, _redo), _setLevel(_guitarId, 1.0));
    expect(_enabled(tester, _redo), isTrue);

    await _silence(tester, server, _vocalId);
    expect(_enabled(tester, _redo), isFalse);
    expect(await _press(tester, server, _undo), _setLevel(_vocalId, 1.0));
    expect(server.problems, isEmpty);
  });

  testWidgets('levels pushed by the server are not undone; undo restores the '
      'level from before the gesture even if someone changed it since', (
    tester,
  ) async {
    // level-push.json: Gitara 0.5, Wokal 1.0, then two changes in REAPER.
    final server = await _startAndOpen(tester, 'level-push.json');

    server.changeProject(); // Gitara -> 1.0, Wokal -> 0.5
    await pumpUntilFound(tester, _levelIn('Wokal', '−6.0 dB'));
    expect(_enabled(tester, _undo), isFalse);

    // The fake server collects our messages only once its script is over.
    await _silence(tester, server, _guitarId, waitForServer: false);
    server.changeProject(); // Gitara -> 0.25, from another phone
    await _waitForLevel(tester, server, _guitarId, 0.0);
    await pumpUntilFound(tester, _levelIn('Gitara', '−12.0 dB'));

    expect(await _press(tester, server, _undo), _setLevel(_guitarId, 1.0));
    expect(_levelIn('Gitara', '0.0 dB'), findsOneWidget);
    expect(_enabled(tester, _undo), isFalse);
    expect(server.problems, isEmpty);
  });

  testWidgets('steps for a source the monitor no longer has are skipped', (
    tester,
  ) async {
    final server = await _startAndOpen(tester, _guitarRemoved());
    await _silence(tester, server, _vocalId, waitForServer: false);
    await _silence(tester, server, _guitarId, waitForServer: false);

    server.changeProject(); // Gitara removed from the monitor in REAPER
    await _waitForLevel(tester, server, _guitarId, 0.0);
    await pumpUntil(
      tester,
      () => _rowOf('Gitara').evaluate().isEmpty,
      description: 'Gitara gone',
    );

    expect(await _press(tester, server, _undo), _setLevel(_vocalId, 1.0));
    expect(_enabled(tester, _undo), isFalse);
    expect(server.problems, isEmpty);
  });
}

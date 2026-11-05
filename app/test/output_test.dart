import 'package:bielik/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

// Same ids as protocol/examples/output.json.
const _monitorId = '{1B6A2C10-0010-4A3E-9C1D-000000000010}';
const _guitarId = '{1B6A2C10-0002-4A3E-9C1D-000000000002}';

/// A watched monitor "Wokal" with one source and the given master state;
/// [after] are the steps that follow the monitor message.
ProtocolExample _example(
  Map<String, Object?> output, {
  List<Map<String, Object?>> after = const [],
}) => ProtocolExample('inline', {
  'steps': [
    {
      'client': {'type': 'hello', 'protocolVersion': 2},
    },
    {
      'server': {'type': 'welcome', 'protocolVersion': 2},
    },
    {
      'server': {
        'type': 'monitors',
        'monitors': [
          {'id': _monitorId, 'name': 'Wokal'},
        ],
      },
    },
    {
      'client': {'type': 'subscribe', 'monitorId': _monitorId},
    },
    {
      'server': {
        'type': 'monitor',
        'id': _monitorId,
        'name': 'Wokal',
        'output': output,
        'sources': [
          {'id': _guitarId, 'name': 'Gitara', 'level': 0.5},
        ],
      },
    },
    ...after,
  ],
});

Future<FakeMixerServer> _openMonitor(
  WidgetTester tester,
  ProtocolExample example,
) async {
  final server = (await tester.runAsync(() => FakeMixerServer.start(example)))!;
  addTearDown(() => tester.runAsync(server.close));

  await tester.pumpWidget(BielikApp(passwordStore: InMemoryPasswordStore()));
  await tester.enterText(find.byKey(const Key('host')), server.host);
  await tester.enterText(find.byKey(const Key('port')), '${server.port}');
  await tester.tap(find.text('Połącz'));
  await pumpUntilFound(tester, find.text('Wokal'));
  await tester.tap(find.text('Wokal'));
  await pumpUntilFound(tester, find.byKey(const Key('level-$_guitarId')));
  return server;
}

Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ListTile));

final _master = find.byKey(const Key('level-master'));

List<Map<String, dynamic>> _outputSets(FakeMixerServer server) => server
    .extraMessages
    .where((message) => message['type'] == 'set_output_level')
    .toList();

bool _enabled(WidgetTester tester, Finder slider) =>
    tester.widget<Slider>(slider).onChanged != null;

void main() {
  testWidgets('Master shows the hardware send level in dB above the sources', (
    tester,
  ) async {
    await _openMonitor(tester, _example({'status': 'ok', 'level': 0.5}));

    expect(
      find.descendant(of: _rowOf('Master'), matching: find.text('−6.0 dB')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('output-banner')), findsNothing);
    expect(
      tester.getTopLeft(_master).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('level-$_guitarId'))).dy),
    );
  });

  testWidgets('double tap on Master resets it to 0 dB; undo is one step', (
    tester,
  ) async {
    final server = await _openMonitor(
      tester,
      _example(
        {'status': 'ok', 'level': 0.5},
        after: [
          {
            'client': {
              'type': 'set_output_level',
              'monitorId': _monitorId,
              'level': 1.0,
            },
          },
        ],
      ),
    );

    await tester.tap(_master);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_master);
    await tester.pump(kDoubleTapTimeout);
    expect(
      find.descendant(of: _rowOf('Master'), matching: find.text('0.0 dB')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('undo')));
    await pumpUntil(
      tester,
      () => _outputSets(server).isNotEmpty,
      description: 'undo sending set_output_level',
    );
    expect(_outputSets(server), [
      {'type': 'set_output_level', 'monitorId': _monitorId, 'level': 0.5},
    ]);
    // The reset was the example's own client step, so it arrived first and
    // matched.
    expect(server.problems, isEmpty);
    expect(
      find.descendant(of: _rowOf('Master'), matching: find.text('−6.0 dB')),
      findsOneWidget,
    );
  });

  for (final (status, text) in [
    ('missing', 'O KURWA, ZJEBAŁO SIĘ: brakuje wyjścia sprzętowego'),
    ('multiple', 'O KURWA, ZJEBAŁEŚ: za dużo wyjść sprzętowych'),
  ]) {
    testWidgets('Master $status: red banner with sparks, Master locked, '
        'sources still work', (tester) async {
      await _openMonitor(tester, _example({'status': status}));

      expect(find.text(text), findsOneWidget);
      final banner = tester.widget<Container>(
        find.byKey(const Key('output-banner')),
      );
      expect(banner.color, Colors.red.shade800);
      expect(find.byKey(const Key('output-sparks')), findsOneWidget);
      expect(_enabled(tester, _master), isFalse);
      expect(
        find.descendant(of: _rowOf('Master'), matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        _enabled(tester, find.byKey(const Key('level-$_guitarId'))),
        isTrue,
      );
    });
  }
}

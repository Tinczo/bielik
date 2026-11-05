// Contract test, app side: the app understands every message the server sends
// in the shared examples (protocol/examples), and the client's own messages
// match what the examples expect it to send.
import 'package:bielik/protocol/messages.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/protocol_examples.dart';

void main() {
  final examples = loadProtocolExamples();

  test('shared protocol examples are present', () {
    expect(examples, isNotEmpty);
  });

  for (final example in examples) {
    group(example.name, () {
      test('every server message decodes to a known message', () {
        for (final json in example.serverMessages) {
          expect(
            ServerMessage.fromJson(json),
            isNot(isA<UnknownMessage>()),
            reason: 'cannot decode $json',
          );
        }
      });
    });
  }

  test('hello matches the handshake example', () {
    final hello = loadProtocolExample('handshake.json').steps.first['client'];
    expect(matchesExample(hello, helloMessage()), isTrue);
  });

  test('hello carries the password as in the password example', () {
    final hello = loadProtocolExample('password.json').steps.first['client'];
    expect(matchesExample(hello, helloMessage(password: 'próba2026')), isTrue);
  });

  test('subscribe matches the subscribe example', () {
    final example = loadProtocolExample('subscribe.json');
    final subscribe = example.steps
        .map((step) => step['client'])
        .whereType<Map<String, dynamic>>()
        .singleWhere((message) => message['type'] == 'subscribe');
    expect(
      matchesExample(
        subscribe,
        subscribeMessage(subscribe['monitorId'] as String),
      ),
      isTrue,
    );
  });

  test('set_level matches the set-level example', () {
    final setLevel = loadProtocolExample('set-level.json').steps
        .map((step) => step['client'])
        .whereType<Map<String, dynamic>>()
        .singleWhere((message) => message['type'] == 'set_level');
    expect(
      matchesExample(
        setLevel,
        setLevelMessage(
          monitorId: setLevel['monitorId'] as String,
          sourceId: setLevel['sourceId'] as String,
          level: (setLevel['level'] as num).toDouble(),
        ),
      ),
      isTrue,
    );
  });

  test('set_output_level matches the output example', () {
    final setOutputLevel = loadProtocolExample('output.json').steps
        .map((step) => step['client'])
        .whereType<Map<String, dynamic>>()
        .singleWhere((message) => message['type'] == 'set_output_level');
    expect(
      matchesExample(
        setOutputLevel,
        setOutputLevelMessage(
          monitorId: setOutputLevel['monitorId'] as String,
          level: (setOutputLevel['level'] as num).toDouble(),
        ),
      ),
      isTrue,
    );
  });

  test('the output example decodes to ok with a level, then a level push', () {
    final messages = loadProtocolExample('output.json')
        .serverMessages
        .map(ServerMessage.fromJson)
        .toList();
    final monitor = messages.whereType<MonitorMessage>().single.monitor;
    expect(monitor.output.status, OutputStatus.ok);
    expect(monitor.output.level, 0.5);
    expect(
      messages.whereType<OutputLevelMessage>().map((m) => m.level),
      [0.25, 1.0],
    );
  });

  test('the unavailable example decodes missing and multiple without level',
      () {
    final monitors = loadProtocolExample('output-unavailable.json')
        .serverMessages
        .map(ServerMessage.fromJson)
        .whereType<MonitorMessage>()
        .map((m) => m.monitor.output)
        .toList();
    expect(monitors.map((o) => o.status), [
      OutputStatus.multiple,
      OutputStatus.missing,
      OutputStatus.ok,
    ]);
    expect(monitors.first.level, isNull);
  });

  test('monitors from the handshake example are decoded in order', () {
    final monitors = loadProtocolExample('handshake.json')
        .serverMessages
        .map(ServerMessage.fromJson)
        .whereType<MonitorsMessage>()
        .single
        .monitors;
    expect(monitors, const [
      Monitor(id: '{1B6A2C10-0001-4A3E-9C1D-000000000001}', name: 'Wokal'),
      Monitor(id: '{1B6A2C10-0003-4A3E-9C1D-000000000003}', name: 'Perkusja'),
    ]);
  });
}

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

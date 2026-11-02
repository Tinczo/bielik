import 'dart:convert';

import 'package:bielik/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

const disconnectedText = 'Rozłączono. Łączę ponownie…';

/// subscribe.json, but REAPER now has Gitara at −12 dB in the monitor.
ProtocolExample subscribeWithGitaraAtMinus12() {
  final example = loadProtocolExample('subscribe.json');
  final json = jsonDecode(jsonEncode(example.json)) as Map<String, dynamic>;
  final monitorStep = (json['steps'] as List).cast<Map<String, dynamic>>().last;
  final sources = (monitorStep['server']['sources'] as List)
      .cast<Map<String, dynamic>>();
  sources.firstWhere((source) => source['name'] == 'Gitara')['level'] = 0.25;
  return ProtocolExample(example.name, json);
}

void main() {
  Future<FakeMixerServer> startServer(WidgetTester tester, {int port = 0}) =>
      tester
          .runAsync(
            () => FakeMixerServer.start(
              loadProtocolExample('subscribe.json'),
              port: port,
            ),
          )
          .then((server) => server!);

  Future<void> openWokal(WidgetTester tester, FakeMixerServer server) async {
    await tester.enterText(find.byKey(const Key('host')), server.host);
    await tester.enterText(find.byKey(const Key('port')), '${server.port}');
    await tester.tap(find.text('Połącz'));
    await pumpUntilFound(tester, find.text('Wokal'));
    await tester.tap(find.text('Wokal'));
    await pumpUntilFound(tester, find.text('−6.0 dB'));
  }

  // Leaves fake time for any socket close-handshake timer still armed.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 6));

  testWidgets(
    'after a Wi-Fi drop Bielik reconnects and shows the monitor again',
    (tester) async {
      final server = await startServer(tester);
      addTearDown(() => tester.runAsync(server.close));
      await tester.pumpWidget(
        BielikApp(passwordStore: InMemoryPasswordStore()),
      );
      await openWokal(tester, server);

      server.example = subscribeWithGitaraAtMinus12();
      await tester.runAsync(server.dropConnections);

      await pumpUntilFound(tester, find.text(disconnectedText));
      await pumpUntilFound(
        tester,
        find.text('−12.0 dB'),
        advance: const Duration(milliseconds: 100),
      );
      expect(find.text(disconnectedText), findsNothing);
      expect(server.connections, 2);
      expect(server.problems, isEmpty);
      await settle(tester);
    },
  );

  testWidgets(
    'after REAPER restarts Bielik keeps trying and comes back on its own',
    (tester) async {
      var server = await startServer(tester);
      await tester.pumpWidget(
        BielikApp(passwordStore: InMemoryPasswordStore()),
      );
      await openWokal(tester, server);
      final port = server.port;

      await tester.runAsync(server.close);
      await pumpUntilFound(tester, find.text(disconnectedText));
      // Several attempts fail while REAPER is down.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text(disconnectedText), findsOneWidget);

      server = await startServer(tester, port: port);
      addTearDown(() => tester.runAsync(server.close));
      server.example = subscribeWithGitaraAtMinus12();
      await pumpUntilFound(
        tester,
        find.text('−12.0 dB'),
        timeout: const Duration(seconds: 10),
        advance: const Duration(milliseconds: 200),
      );
      expect(find.text(disconnectedText), findsNothing);
      expect(server.problems, isEmpty);
      await settle(tester);
    },
  );
}

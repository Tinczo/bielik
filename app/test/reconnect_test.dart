import 'dart:convert';

import 'package:bielik/app.dart';
import 'package:flutter/gestures.dart';
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

const gitaraId = '{1B6A2C10-0002-4A3E-9C1D-000000000002}';
const wokalId = '{1B6A2C10-0001-4A3E-9C1D-000000000001}';

Slider gitaraSlider(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(const Key('level-$gitaraId')));

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
      expect(gitaraSlider(tester).onChanged, isNull);
      // The last known state stays on screen meanwhile.
      expect(find.text('−6.0 dB'), findsOneWidget);

      await pumpUntilFound(
        tester,
        find.text('−12.0 dB'),
        advance: const Duration(milliseconds: 100),
      );
      expect(find.text(disconnectedText), findsNothing);
      expect(gitaraSlider(tester).onChanged, isNotNull);
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

  testWidgets(
    'undo and redo wait for the connection, and the history survives the drop',
    (tester) async {
      final server = await startServer(tester);
      addTearDown(() => tester.runAsync(server.close));
      await tester.pumpWidget(
        BielikApp(passwordStore: InMemoryPasswordStore()),
      );
      await openWokal(tester, server);

      final undo = find.byKey(const Key('undo'));
      final redo = find.byKey(const Key('redo'));
      bool enabled(Finder button) =>
          tester.widget<IconButton>(button).onPressed != null;
      Iterable<Object?> levelsSent() => server.extraMessages
          .where((message) => message['type'] == 'set_level')
          .map((message) => message['level']);
      Future<void> silence(String sourceId) async {
        final slider = find.byKey(Key('level-$sourceId'));
        await tester.drag(slider, Offset(-tester.getSize(slider).width, 0));
        await tester.pump(kDoubleTapTimeout);
      }

      await silence(gitaraId);
      await silence(wokalId);
      await pumpUntil(
        tester,
        () => levelsSent().where((level) => level == 0).length >= 2,
        description: 'both levels reached the server',
      );
      await tester.tap(undo);
      await tester.pump();
      expect(enabled(undo), isTrue);
      expect(enabled(redo), isTrue);

      await tester.runAsync(server.dropConnections);
      await pumpUntilFound(tester, find.text(disconnectedText));
      expect(enabled(undo), isFalse);
      expect(enabled(redo), isFalse);

      await pumpUntil(
        tester,
        () => find.text(disconnectedText).evaluate().isEmpty,
        advance: const Duration(milliseconds: 100),
        description: 'reconnected',
      );
      expect(enabled(undo), isTrue);
      expect(enabled(redo), isTrue);

      await pumpUntil(
        tester,
        () =>
            server.connections == 2 &&
            find.text('−6.0 dB').evaluate().isNotEmpty,
        description: 'monitor back from the server',
      );
      final sentBefore = levelsSent().length;
      await tester.tap(undo);
      await pumpUntil(
        tester,
        () => levelsSent().length > sentBefore,
        description: 'undo reached the server',
      );
      expect(levelsSent().last, 0.5);
      expect(server.problems, isEmpty);
      await settle(tester);
    },
  );

  testWidgets(
    'when the monitor is gone after reconnecting Bielik goes back to the list',
    (tester) async {
      final server = await startServer(tester);
      addTearDown(() => tester.runAsync(server.close));
      await tester.pumpWidget(
        BielikApp(passwordStore: InMemoryPasswordStore()),
      );
      await openWokal(tester, server);

      // REAPER came back with another project open.
      server.example = loadProtocolExample('handshake.json');
      await tester.runAsync(server.dropConnections);

      await pumpUntilFound(
        tester,
        find.text('Odsłuch „Wokal” został usunięty.'),
        advance: const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(find.text('Odsłuchy'), findsOneWidget);
      expect(find.text('Perkusja'), findsOneWidget);
      expect(server.extraMessages, isEmpty, reason: 'no subscribe sent');
      expect(server.problems, isEmpty);
      await settle(tester);
    },
  );
}

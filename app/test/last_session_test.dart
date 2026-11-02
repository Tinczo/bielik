import 'package:bielik/app.dart';
import 'package:bielik/storage/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/in_memory_session_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

const wokalMonitorId = '{1B6A2C10-0010-4A3E-9C1D-000000000010}';

void main() {
  Future<FakeMixerServer> startServer(WidgetTester tester) async {
    final server = (await tester.runAsync(
      () => FakeMixerServer.start(loadProtocolExample('subscribe.json')),
    ))!;
    addTearDown(() => tester.runAsync(server.close));
    return server;
  }

  testWidgets(
    'Bielik remembers the server and the monitor the musician opened',
    (tester) async {
      final server = await startServer(tester);
      final sessions = InMemorySessionStore();
      await tester.pumpWidget(
        BielikApp(
          passwordStore: InMemoryPasswordStore(),
          sessionStore: sessions,
        ),
      );

      await tester.enterText(find.byKey(const Key('host')), server.host);
      await tester.enterText(find.byKey(const Key('port')), '${server.port}');
      await tester.tap(find.text('Połącz'));
      await pumpUntilFound(tester, find.text('Wokal'));
      await tester.tap(find.text('Wokal'));
      await pumpUntilFound(tester, find.text('Gitara'));

      expect(sessions.session?.host, server.host);
      expect(sessions.session?.port, server.port);
      expect(sessions.session?.monitorId, wokalMonitorId);
    },
  );

  testWidgets(
    'on the next start Bielik goes back to the last server and monitor '
    'by itself',
    (tester) async {
      final server = await startServer(tester);
      await tester.pumpWidget(
        BielikApp(
          passwordStore: InMemoryPasswordStore('próba2026'),
          sessionStore: InMemorySessionStore(
            LastSession(
              host: server.host,
              port: server.port,
              monitorId: wokalMonitorId,
            ),
          ),
        ),
      );

      await pumpUntilFound(tester, find.text('−6.0 dB'));
      expect(find.text('Gitara'), findsOneWidget);
      expect(server.problems, isEmpty);

      // Back goes to the monitor list, as if the musician had picked it.
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Odsłuchy'), findsOneWidget);
    },
  );

  testWidgets('when the last server is gone Bielik stays on the connect screen '
      'with its address filled in', (tester) async {
    final server = await startServer(tester);
    final port = server.port;
    await tester.runAsync(server.close);
    await tester.pumpWidget(
      BielikApp(
        passwordStore: InMemoryPasswordStore(),
        sessionStore: InMemorySessionStore(
          LastSession(host: '127.0.0.1', port: port),
        ),
      ),
    );

    await pumpUntilFound(
      tester,
      find.text('Nie udało się połączyć z 127.0.0.1:$port.'),
    );
    expect(find.widgetWithText(TextField, '127.0.0.1'), findsOneWidget);
    expect(find.widgetWithText(TextField, '$port'), findsOneWidget);
  });
}

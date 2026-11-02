import 'package:bielik/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

void main() {
  Future<FakeMixerServer> startServer(
    WidgetTester tester,
    String example,
  ) async {
    final server = (await tester.runAsync(
      () => FakeMixerServer.start(loadProtocolExample(example)),
    ))!;
    addTearDown(() => tester.runAsync(server.close));
    return server;
  }

  // When the app closes a socket the server is closing too, dart:io may arm a
  // close-handshake timeout timer, which in fake time stays pending; let it run.
  Future<void> settleRefusedSocket(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 6));

  Future<void> connect(
    WidgetTester tester,
    FakeMixerServer server, {
    String? password,
  }) async {
    await tester.enterText(find.byKey(const Key('host')), server.host);
    await tester.enterText(find.byKey(const Key('port')), '${server.port}');
    if (password != null) {
      await tester.enterText(find.byKey(const Key('password')), password);
    }
    await tester.tap(find.text('Połącz'));
  }

  testWidgets('musician gives the band password and Bielik remembers it', (
    tester,
  ) async {
    final server = await startServer(tester, 'password.json');
    final store = InMemoryPasswordStore();
    await tester.pumpWidget(BielikApp(passwordStore: store));

    await connect(tester, server, password: 'próba2026');

    await pumpUntilFound(tester, find.text('Wokal'));
    expect(server.problems, isEmpty);
    expect(store.password, 'próba2026');
  });

  testWidgets('a remembered password is filled in on the next start', (
    tester,
  ) async {
    final server = await startServer(tester, 'password.json');
    final store = InMemoryPasswordStore('próba2026');
    await tester.pumpWidget(BielikApp(passwordStore: store));
    await tester.pump();

    await connect(tester, server);

    await pumpUntilFound(tester, find.text('Wokal'));
    expect(server.problems, isEmpty);
  });

  testWidgets('a wrong password says so and is not remembered', (tester) async {
    final server = await startServer(tester, 'bad-password.json');
    final store = InMemoryPasswordStore('stare');
    await tester.pumpWidget(BielikApp(passwordStore: store));
    await tester.pump();

    await connect(tester, server, password: 'zgaduję');

    await pumpUntilFound(
      tester,
      find.text('Złe hasło. Zapytaj zespół o aktualne hasło.'),
    );
    expect(find.textContaining('Nie udało się połączyć'), findsNothing);
    expect(find.text('Odsłuchy'), findsNothing);
    expect(store.password, 'stare');
    await settleRefusedSocket(tester);
  });

  testWidgets('an extension speaking another protocol version says so', (
    tester,
  ) async {
    // The example's client sends a version the server does not speak; Bielik
    // sends its own, so only the server's answer matters here.
    final server = await startServer(tester, 'unsupported-version.json');
    await tester.pumpWidget(BielikApp(passwordStore: InMemoryPasswordStore()));

    await connect(tester, server);

    await pumpUntilFound(
      tester,
      find.text(
        'Rozszerzenie w REAPERze ma inną wersję niż Bielik. '
        'Zaktualizuj Rozszerzenie albo Bielika.',
      ),
    );
    expect(find.textContaining('Nie udało się połączyć'), findsNothing);
    expect(find.textContaining('Złe hasło'), findsNothing);
    await settleRefusedSocket(tester);
  });
}

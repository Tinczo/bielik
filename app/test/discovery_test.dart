import 'package:bielik/app.dart';
import 'package:bielik/discovery/laptop_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_laptop_discovery.dart';
import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

void main() {
  testWidgets('musician taps a discovered laptop and sees its monitors',
      (tester) async {
    final server = (await tester.runAsync(
      () => FakeMixerServer.start(loadProtocolExample('handshake.json')),
    ))!;
    addTearDown(() => tester.runAsync(server.close));
    final discovery = FakeLaptopDiscovery();

    await tester.pumpWidget(BielikApp(
      discovery: discovery,
      passwordStore: InMemoryPasswordStore(),
    ));
    discovery.found([
      DiscoveredLaptop(name: 'STUDIO-LAPTOP', host: server.host, port: server.port),
    ]);
    await tester.pump();

    await tester.tap(find.text('STUDIO-LAPTOP'));
    await pumpUntilFound(tester, find.text('Wokal'));
    expect(find.text('Perkusja'), findsOneWidget);
    expect(server.problems, isEmpty);
  });

  testWidgets('musician sees the search going on and the manual address',
      (tester) async {
    final discovery = FakeLaptopDiscovery();
    const studio = DiscoveredLaptop(name: 'STUDIO', host: '10.0.0.5', port: 8790);

    await tester.pumpWidget(BielikApp(
      discovery: discovery,
      passwordStore: InMemoryPasswordStore(),
    ));
    expect(find.text('Szukam laptopów w sieci…'), findsOneWidget);
    expect(find.byKey(const Key('host')), findsOneWidget);

    discovery.found([studio]);
    await tester.pump();
    expect(find.text('STUDIO'), findsOneWidget);
    expect(find.text('Szukam laptopów w sieci…'), findsNothing);

    discovery.found([]);
    await tester.pump();
    expect(find.text('STUDIO'), findsNothing);
    expect(find.text('Szukam laptopów w sieci…'), findsOneWidget);
  });

  testWidgets('musician is told to use the manual address when discovery fails',
      (tester) async {
    final discovery = FakeLaptopDiscovery();

    await tester.pumpWidget(BielikApp(
      discovery: discovery,
      passwordStore: InMemoryPasswordStore(),
    ));
    discovery.fails();
    await tester.pump();

    expect(
      find.text('Nie udało się wyszukać laptopów w sieci. Wpisz adres ręcznie.'),
      findsOneWidget,
    );
    expect(find.text('Szukam laptopów w sieci…'), findsNothing);
    expect(find.byKey(const Key('host')), findsOneWidget);
  });
}

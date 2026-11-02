import 'package:bielik/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

void main() {
  testWidgets('musician enters the address and sees the monitors of the project',
      (tester) async {
    final server = (await tester.runAsync(
      () => FakeMixerServer.start(loadProtocolExample('handshake.json')),
    ))!;
    addTearDown(() => tester.runAsync(server.close));

    await tester.pumpWidget(const BielikApp());
    expect(find.text('Bielik'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('host')), server.host);
    await tester.enterText(find.byKey(const Key('port')), '${server.port}');
    await tester.tap(find.text('Połącz'));

    await pumpUntilFound(tester, find.text('Wokal'));
    expect(find.text('Perkusja'), findsOneWidget);
    expect(find.text('Gitara'), findsNothing);
    expect(server.problems, isEmpty);
  });

  testWidgets('musician sees an error when nothing listens at the address',
      (tester) async {
    await tester.pumpWidget(const BielikApp());

    await tester.enterText(find.byKey(const Key('host')), '127.0.0.1');
    await tester.enterText(find.byKey(const Key('port')), '1');
    await tester.tap(find.text('Połącz'));

    await pumpUntilFound(
      tester,
      find.text('Nie udało się połączyć z 127.0.0.1:1.'),
    );
    expect(find.text('Odsłuchy'), findsNothing);
  });
}

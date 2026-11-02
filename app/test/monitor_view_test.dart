import 'package:bielik/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

void main() {
  testWidgets(
    'musician picks a monitor and sees its sources with levels in dB',
    (tester) async {
      final server = (await tester.runAsync(
        () => FakeMixerServer.start(loadProtocolExample('subscribe.json')),
      ))!;
      addTearDown(() => tester.runAsync(server.close));

      await tester.pumpWidget(BielikApp(passwordStore: InMemoryPasswordStore()));
      await tester.enterText(find.byKey(const Key('host')), server.host);
      await tester.enterText(find.byKey(const Key('port')), '${server.port}');
      await tester.tap(find.text('Połącz'));
      await pumpUntilFound(tester, find.text('Wokal'));

      await tester.tap(find.text('Wokal'));
      await pumpUntilFound(tester, find.text('Gitara'));

      final sources = find.byKey(const Key('sources'));
      final rows = [
        for (final name in ['Gitara', 'Wokal', 'Perkusja', 'Bas'])
          find.descendant(of: sources, matching: find.text(name)),
      ];
      for (final row in rows) {
        expect(row, findsOneWidget);
      }
      // Sources appear in receive order; the duplicate Gitara receive is hidden.
      final tops = [for (final row in rows) tester.getTopLeft(row).dy];
      expect(tops, orderedEquals([...tops]..sort()));

      expect(find.text('−6.0 dB'), findsOneWidget);
      expect(find.text('0.0 dB'), findsOneWidget);
      expect(find.text('−∞ dB'), findsOneWidget);
      expect(find.text('+6.0 dB'), findsOneWidget);
      expect(server.problems, isEmpty);
    },
  );
}

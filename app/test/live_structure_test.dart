import 'package:bielik/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

/// Connects to a fake server playing [exampleName] and opens the monitor
/// "Wokal", waiting until [firstSource] is shown.
Future<FakeMixerServer> openVocalMonitor(
  WidgetTester tester,
  String exampleName, {
  required String firstSource,
}) async {
  final server = (await tester.runAsync(
    () => FakeMixerServer.start(loadProtocolExample(exampleName)),
  ))!;
  addTearDown(() => tester.runAsync(server.close));

  await tester.pumpWidget(const BielikApp());
  await tester.enterText(find.byKey(const Key('host')), server.host);
  await tester.enterText(find.byKey(const Key('port')), '${server.port}');
  await tester.tap(find.text('Połącz'));
  await pumpUntilFound(tester, find.text('Wokal'));
  await tester.tap(find.text('Wokal'));
  await pumpUntilFound(tester, find.text(firstSource));
  return server;
}

void main() {
  testWidgets(
    'new and renamed sources and new monitors show up without reconnecting',
    (tester) async {
      final server = await openVocalMonitor(
        tester,
        'live-structure-change.json',
        firstSource: 'Gitara',
      );

      server.changeProject();
      final sources = find.byKey(const Key('sources'));
      await pumpUntilFound(
        tester,
        find.descendant(of: sources, matching: find.text('Gitara akustyczna')),
      );
      expect(
        find.descendant(of: sources, matching: find.text('Perkusja')),
        findsOneWidget,
      );
      expect(find.text('Gitara'), findsNothing);

      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Wokal'), findsOneWidget);
      expect(find.text('Perkusja'), findsOneWidget);
      expect(server.problems, isEmpty);
    },
  );

  testWidgets(
    'musician goes back to the list with a message when their monitor is removed',
    (tester) async {
      final server = await openVocalMonitor(
        tester,
        'monitor-removed.json',
        firstSource: 'Gitara',
      );

      server.changeProject();
      await pumpUntilFound(tester, find.textContaining('został usunięty'));
      await tester.pumpAndSettle();

      expect(find.text('Odsłuchy'), findsOneWidget);
      expect(find.byKey(const Key('sources')), findsNothing);
      expect(find.text('Perkusja'), findsOneWidget);
      expect(find.text('Wokal'), findsNothing);
      expect(find.text('Odsłuch „Wokal” został usunięty.'), findsOneWidget);
      expect(server.problems, isEmpty);
    },
  );
}

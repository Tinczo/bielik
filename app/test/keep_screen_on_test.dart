import 'package:bielik/app.dart';
import 'package:bielik/platform/screen_wake_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mixer_server.dart';
import 'support/in_memory_password_store.dart';
import 'support/in_memory_session_store.dart';
import 'support/protocol_examples.dart';
import 'support/real_io.dart';

/// Records whether the phone was asked to keep its screen on.
class FakeScreenWakeLock implements ScreenWakeLock {
  bool on = false;

  @override
  Future<void> keepOn(bool on) async => this.on = on;
}

void main() {
  testWidgets('the screen stays on only while a monitor is open', (
    tester,
  ) async {
    final server = (await tester.runAsync(
      () => FakeMixerServer.start(loadProtocolExample('subscribe.json')),
    ))!;
    addTearDown(() => tester.runAsync(server.close));
    final wakeLock = FakeScreenWakeLock();
    await tester.pumpWidget(
      BielikApp(
        passwordStore: InMemoryPasswordStore(),
        sessionStore: InMemorySessionStore(),
        screenWakeLock: wakeLock,
      ),
    );

    await tester.enterText(find.byKey(const Key('host')), server.host);
    await tester.enterText(find.byKey(const Key('port')), '${server.port}');
    await tester.tap(find.text('Połącz'));
    await pumpUntilFound(tester, find.text('Wokal'));
    expect(wakeLock.on, isFalse);

    await tester.tap(find.text('Wokal'));
    await pumpUntilFound(tester, find.text('Gitara'));
    expect(wakeLock.on, isTrue);

    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(wakeLock.on, isFalse);
  });
}

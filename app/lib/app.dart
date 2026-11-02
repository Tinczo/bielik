import 'package:flutter/material.dart';

import 'discovery/laptop_discovery.dart';
import 'platform/screen_wake_lock.dart';
import 'storage/password_store.dart';
import 'storage/session_store.dart';
import 'ui/connect_screen.dart';

class BielikApp extends StatelessWidget {
  const BielikApp({
    super.key,
    this.discovery,
    this.passwordStore = const SecurePasswordStore(),
    this.sessionStore = const PreferencesSessionStore(),
    this.screenWakeLock = const WakelockPlusScreenWakeLock(),
    this.keepAlive,
  });

  /// Finds laptops on the network; without it only the manual address works.
  final LaptopDiscovery? discovery;

  /// Remembers the band password between rehearsals.
  final PasswordStore passwordStore;

  /// Remembers the last server and monitor, to go back to them on start.
  final SessionStore sessionStore;

  /// Keeps the screen on while a monitor is open.
  final ScreenWakeLock screenWakeLock;

  /// How often to check that the laptop still answers (see
  /// `MixerClient.connect`); null relies on the socket closing.
  final Duration? keepAlive;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: ConnectScreen(
        passwordStore: passwordStore,
        sessionStore: sessionStore,
        screenWakeLock: screenWakeLock,
        discovery: discovery,
        keepAlive: keepAlive,
      ),
    );
  }
}

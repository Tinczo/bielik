import 'package:flutter/material.dart';

import 'discovery/laptop_discovery.dart';
import 'storage/password_store.dart';
import 'ui/connect_screen.dart';

class BielikApp extends StatelessWidget {
  const BielikApp({
    super.key,
    this.discovery,
    this.passwordStore = const SecurePasswordStore(),
  });

  /// Finds laptops on the network; without it only the manual address works.
  final LaptopDiscovery? discovery;

  /// Remembers the band password between rehearsals.
  final PasswordStore passwordStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: ConnectScreen(passwordStore: passwordStore, discovery: discovery),
    );
  }
}

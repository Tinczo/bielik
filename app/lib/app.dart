import 'package:flutter/material.dart';

import 'discovery/laptop_discovery.dart';
import 'history/level_history.dart';
import 'storage/password_store.dart';
import 'ui/connect_screen.dart';

class BielikApp extends StatefulWidget {
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
  State<BielikApp> createState() => _BielikAppState();
}

class _BielikAppState extends State<BielikApp> {
  /// Undo history of every monitor, for as long as the app runs.
  final _histories = LevelHistories();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      builder: (context, child) =>
          LevelHistoryScope(histories: _histories, child: child!),
      home: ConnectScreen(
        passwordStore: widget.passwordStore,
        discovery: widget.discovery,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'storage/password_store.dart';
import 'ui/connect_screen.dart';

class BielikApp extends StatelessWidget {
  const BielikApp({
    super.key,
    this.passwordStore = const SecurePasswordStore(),
  });

  final PasswordStore passwordStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: ConnectScreen(passwordStore: passwordStore),
    );
  }
}

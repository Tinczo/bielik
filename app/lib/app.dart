import 'package:flutter/material.dart';

import 'ui/connect_screen.dart';

class BielikApp extends StatelessWidget {
  const BielikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: const ConnectScreen(),
    );
  }
}

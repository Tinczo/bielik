import 'package:flutter/material.dart';

import 'discovery/laptop_discovery.dart';
import 'ui/connect_screen.dart';

class BielikApp extends StatelessWidget {
  const BielikApp({super.key, this.discovery});

  /// Finds laptops on the network; without it only the manual address works.
  final LaptopDiscovery? discovery;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bielik',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: ConnectScreen(discovery: discovery),
    );
  }
}

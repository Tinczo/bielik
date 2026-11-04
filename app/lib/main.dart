import 'package:flutter/material.dart';

import 'app.dart';
import 'discovery/bonsoir_laptop_discovery.dart';

void main() {
  runApp(
    BielikApp(
      discovery: BonsoirLaptopDiscovery(),
      keepAlive: const Duration(seconds: 3),
    ),
  );
}

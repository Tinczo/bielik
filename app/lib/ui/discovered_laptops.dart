import 'dart:async';

import 'package:flutter/material.dart';

import '../discovery/laptop_discovery.dart';

/// Laptops found on the network; tapping one connects to it.
class DiscoveredLaptops extends StatefulWidget {
  const DiscoveredLaptops({
    super.key,
    required this.discovery,
    required this.onSelected,
    this.enabled = true,
  });

  final LaptopDiscovery discovery;
  final void Function(DiscoveredLaptop laptop) onSelected;
  final bool enabled;

  @override
  State<DiscoveredLaptops> createState() => _DiscoveredLaptopsState();
}

class _DiscoveredLaptopsState extends State<DiscoveredLaptops> {
  StreamSubscription<List<DiscoveredLaptop>>? _subscription;
  List<DiscoveredLaptop> _laptops = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.discovery.laptops().listen(
          (laptops) => setState(() => _laptops = laptops),
          onError: (Object _) => setState(() => _failed = true),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_failed)
          const ListTile(
            leading: Icon(Icons.wifi_off),
            title: Text(
              'Nie udało się wyszukać laptopów w sieci. Wpisz adres ręcznie.',
            ),
          )
        else if (_laptops.isEmpty)
          const ListTile(
            leading: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Szukam laptopów w sieci…'),
          ),
        for (final laptop in _laptops)
          ListTile(
            leading: const Icon(Icons.laptop),
            title: Text(laptop.name),
            subtitle: Text('${laptop.host}:${laptop.port}'),
            enabled: widget.enabled,
            onTap: () => widget.onSelected(laptop),
          ),
      ],
    );
  }
}

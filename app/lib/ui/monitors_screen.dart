import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import '../protocol/mixer_client.dart';
import 'monitor_screen.dart';

/// List of the monitors in the active REAPER project.
class MonitorsScreen extends StatelessWidget {
  const MonitorsScreen({super.key, required this.client});

  final MixerClient client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odsłuchy')),
      body: ValueListenableBuilder<List<Monitor>?>(
        valueListenable: client.monitors,
        builder: (context, monitors, _) {
          if (monitors == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (monitors.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Projekt nie ma odsłuchów. Nazwij ścieżkę w REAPERze '
                  '„Odsłuch: …”, żeby się tu pojawiła.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final monitor in monitors)
                ListTile(
                  leading: const Icon(Icons.headphones),
                  title: Text(monitor.name),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MonitorScreen(client: client, monitor: monitor),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

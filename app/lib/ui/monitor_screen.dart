import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import '../protocol/mixer_client.dart';
import 'source_tile.dart';

/// One monitor: its sources, each with a slider for its level.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, required this.client, required this.monitor});

  final MixerClient client;
  final Monitor monitor;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  void initState() {
    super.initState();
    widget.client.subscribe(widget.monitor.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.monitor.name)),
      body: ValueListenableBuilder<MonitorState?>(
        valueListenable: widget.client.monitor,
        builder: (context, monitor, _) {
          if (monitor == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (monitor.sources.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ten odsłuch nie ma źródeł. Dodaj w REAPERze receive '
                  'do jego ścieżki.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            key: const Key('sources'),
            children: [
              for (final source in monitor.sources)
                SourceTile(
                  key: ValueKey(source.id),
                  source: source,
                  onLevel: (level) => widget.client.setLevel(source.id, level),
                ),
            ],
          );
        },
      ),
    );
  }
}

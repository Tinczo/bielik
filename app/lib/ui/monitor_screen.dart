import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import '../protocol/mixer_client.dart';
import 'source_tile.dart';

/// One monitor: its sources, each with a slider for its level. Follows
/// structure changes made in REAPER; when the monitor is removed there, goes
/// back to the list with a message.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, required this.client, required this.monitor});

  final MixerClient client;
  final Monitor monitor;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final StreamSubscription<String> _removed;

  /// Monitor name; follows renames made in REAPER.
  late String _name = widget.monitor.name;

  @override
  void initState() {
    super.initState();
    _removed = widget.client.monitorRemoved.listen(_onMonitorRemoved);
    widget.client.monitor.addListener(_onMonitorChanged);
    widget.client.subscribe(widget.monitor.id);
  }

  @override
  void dispose() {
    _removed.cancel();
    widget.client.monitor.removeListener(_onMonitorChanged);
    super.dispose();
  }

  void _onMonitorChanged() {
    final monitor = widget.client.monitor.value;
    if (monitor != null && monitor.name != _name) {
      setState(() => _name = monitor.name);
    }
  }

  void _onMonitorRemoved(String monitorId) {
    if (monitorId != widget.monitor.id || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Odsłuch „$_name” został usunięty.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
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

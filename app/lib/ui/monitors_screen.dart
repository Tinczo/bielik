import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import '../protocol/mixer_client.dart';
import '../storage/session_store.dart';
import 'connection_status_bar.dart';
import 'monitor_screen.dart';

/// List of the monitors in the active REAPER project.
class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({
    super.key,
    required this.client,
    required this.sessionStore,
    this.reopenMonitorId,
  });

  final MixerClient client;

  /// Remembers the monitor the musician opens.
  final SessionStore sessionStore;

  /// Monitor to open as soon as the list arrives, if it is still there (the
  /// one open when Bielik last ran).
  final String? reopenMonitorId;

  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.reopenMonitorId != null) {
      widget.client.monitors.addListener(_reopenMonitor);
      WidgetsBinding.instance.addPostFrameCallback((_) => _reopenMonitor());
    }
  }

  @override
  void dispose() {
    widget.client.monitors.removeListener(_reopenMonitor);
    super.dispose();
  }

  void _reopenMonitor() {
    final monitors = widget.client.monitors.value;
    if (monitors == null || !mounted) return;
    widget.client.monitors.removeListener(_reopenMonitor);
    for (final monitor in monitors) {
      if (monitor.id == widget.reopenMonitorId) {
        _open(monitor);
        return;
      }
    }
  }

  void _open(Monitor monitor) {
    final client = widget.client;
    rememberSession(
      widget.sessionStore,
      LastSession(host: client.host, port: client.port, monitorId: monitor.id),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionStatusBar(
          client: client,
          child: MonitorScreen(client: client, monitor: monitor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odsłuchy')),
      body: ValueListenableBuilder<List<Monitor>?>(
        valueListenable: widget.client.monitors,
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
                  onTap: () => _open(monitor),
                ),
            ],
          );
        },
      ),
    );
  }
}

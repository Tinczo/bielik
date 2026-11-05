import 'dart:async';

import 'package:flutter/material.dart';

import '../history/level_history.dart';
import '../protocol/messages.dart';
import '../protocol/mixer_client.dart';
import 'source_tile.dart';

/// One monitor: its sources, each with a slider for its level. Follows
/// structure changes made in REAPER; when the monitor is removed there, goes
/// back to the list with a message. The musician can undo and redo their own
/// level changes in this monitor, step by step.
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

  /// The musician's own level changes in this monitor; outlives the screen.
  LevelHistory get _history =>
      LevelHistoryScope.of(context).of(widget.monitor.id);

  /// Whether the shown monitor still has [sourceId]; for the Master
  /// ([LevelStep.outputId]) whether it has exactly one hardware send.
  bool _exists(String sourceId) {
    final monitor = widget.client.monitor.value;
    if (monitor == null) return false;
    if (sourceId == LevelStep.outputId) return monitor.output.available;
    return monitor.sources.any((source) => source.id == sourceId);
  }

  void _setStepLevel(LevelStep step, double level) {
    if (step.isOutput) {
      widget.client.setOutputLevel(level);
    } else {
      widget.client.setLevel(step.sourceId, level);
    }
  }

  /// Undo and redo send levels, so they wait for the connection.
  bool get _connected =>
      widget.client.connection.value == ConnectionStatus.connected;

  void _undo() {
    final step = _history.undo(_exists);
    if (step != null) _setStepLevel(step, step.before);
  }

  void _redo() {
    final step = _history.redo(_exists);
    if (step != null) _setStepLevel(step, step.after);
  }

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

  /// The Master at the top: a slider for the hardware send, or a red banner
  /// (with sparks) and a locked slider when the monitor does not have exactly
  /// one hardware send.
  Widget _master(MonitorState monitor, bool connected) {
    final output = monitor.output;
    final tile = SourceTile(
      key: const Key('master'),
      sliderKey: const Key('level-master'),
      source: Source(id: 'master', name: 'Master', level: output.level ?? 1.0),
      highlighted: true,
      levelAvailable: output.available,
      enabled: connected,
      onLevel: widget.client.setOutputLevel,
      onGesture: (before, after) => _history.record(
        LevelStep.output(before: before, after: after),
      ),
    );
    final problem = switch (output.status) {
      OutputStatus.ok => null,
      OutputStatus.missing =>
        'O KURWA, ZJEBAŁO SIĘ: brakuje wyjścia sprzętowego',
      OutputStatus.multiple =>
        'O KURWA, ZJEBAŁEŚ: za dużo wyjść sprzętowych',
    };
    if (problem == null) return tile;
    return Column(
      children: [
        Container(
          key: const Key('output-banner'),
          color: Colors.red.shade800,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.electric_bolt,
                key: Key('output-sparks'),
                color: Colors.yellowAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  problem,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        tile,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([
              _history,
              widget.client.monitor,
              widget.client.connection,
            ]),
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('undo'),
                  tooltip: 'Cofnij',
                  icon: const Icon(Icons.undo),
                  onPressed: _connected && _history.canUndo(_exists)
                      ? _undo
                      : null,
                ),
                IconButton(
                  key: const Key('redo'),
                  tooltip: 'Ponów',
                  icon: const Icon(Icons.redo),
                  onPressed: _connected && _history.canRedo(_exists)
                      ? _redo
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<MonitorState?>(
        valueListenable: widget.client.monitor,
        builder: (context, monitor, _) {
          if (monitor == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<ConnectionStatus>(
            valueListenable: widget.client.connection,
            builder: (context, connection, _) => ListView(
              key: const Key('sources'),
              children: [
                _master(monitor, connection == ConnectionStatus.connected),
                if (monitor.sources.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Ten odsłuch nie ma źródeł. Dodaj w REAPERze receive '
                      'do jego ścieżki.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final source in monitor.sources)
                  SourceTile(
                    key: ValueKey(source.id),
                    source: source,
                    enabled: connection == ConnectionStatus.connected,
                    onLevel: (level) =>
                        widget.client.setLevel(source.id, level),
                    onGesture: (before, after) => _history.record(
                      LevelStep(
                        sourceId: source.id,
                        before: before,
                        after: after,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

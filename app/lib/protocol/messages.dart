/// Wire messages of the protocol described in docs/protocol.md.
library;

const int protocolVersion = 2;

/// A monitor ("odsłuch"): one musician's personal mix.
class Monitor {
  const Monitor({required this.id, required this.name});

  /// GUID of the monitor's REAPER track.
  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Monitor && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Monitor($id, $name)';
}

/// A source ("źródło") of a monitor: a track the monitor receives audio from.
class Source {
  const Source({required this.id, required this.name, required this.level});

  /// GUID of the source track.
  final String id;
  final String name;

  /// Receive volume, linear: 1.0 = 0 dB, 0 = -inf.
  final double level;
}

/// Whether a monitor has exactly one hardware send, which the Master slider
/// controls.
enum OutputStatus {
  /// Exactly one hardware send.
  ok,

  /// No hardware send.
  missing,

  /// More than one hardware send.
  multiple,
}

/// The monitor's master ("Master"): the volume of its hardware send.
class Output {
  const Output(this.status, [this.level]);

  final OutputStatus status;

  /// Linear, 1.0 = 0 dB; only when [status] is [OutputStatus.ok].
  final double? level;

  /// Whether the Master can be changed.
  bool get available => status == OutputStatus.ok && level != null;
}

/// Full state of one monitor: its master and its sources in receive order.
class MonitorState {
  const MonitorState({
    required this.id,
    required this.name,
    required this.output,
    required this.sources,
  });

  final String id;
  final String name;
  final Output output;
  final List<Source> sources;

  /// This state with the master at [level].
  MonitorState withOutputLevel(double level) => MonitorState(
    id: id,
    name: name,
    output: Output(OutputStatus.ok, level),
    sources: sources,
  );

  /// This state with [sourceId] at [level].
  MonitorState withLevel(String sourceId, double level) => MonitorState(
    id: id,
    name: name,
    output: output,
    sources: [
      for (final source in sources)
        source.id == sourceId
            ? Source(id: source.id, name: source.name, level: level)
            : source,
    ],
  );
}

Map<String, Object?> subscribeMessage(String monitorId) => {
      'type': 'subscribe',
      'monitorId': monitorId,
    };

/// Sets the [level] (linear, 1.0 = 0 dB) of one source in one monitor.
Map<String, Object?> setLevelMessage({
  required String monitorId,
  required String sourceId,
  required double level,
}) =>
    {
      'type': 'set_level',
      'monitorId': monitorId,
      'sourceId': sourceId,
      'level': level,
    };

/// Sets the master [level] (linear, 1.0 = 0 dB) of one monitor.
Map<String, Object?> setOutputLevelMessage({
  required String monitorId,
  required double level,
}) =>
    {'type': 'set_output_level', 'monitorId': monitorId, 'level': level};

Map<String, Object?> helloMessage({String password = ''}) => {
      'type': 'hello',
      'protocolVersion': protocolVersion,
      'password': password,
    };

/// A message sent by the server.
sealed class ServerMessage {
  const ServerMessage();

  /// Decodes a JSON object; never throws. Unrecognised input becomes
  /// [UnknownMessage].
  static ServerMessage fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return UnknownMessage(json);
    try {
      return switch (json['type']) {
        'welcome' => WelcomeMessage(json['protocolVersion'] as int),
        'monitors' => MonitorsMessage([
            for (final monitor in json['monitors'] as List)
              Monitor(
                id: monitor['id'] as String,
                name: monitor['name'] as String,
              ),
          ]),
        'monitor' => MonitorMessage(
            MonitorState(
              id: json['id'] as String,
              name: json['name'] as String,
              output: _decodeOutput(json['output']),
              sources: [
                for (final source in json['sources'] as List)
                  Source(
                    id: source['id'] as String,
                    name: source['name'] as String,
                    level: (source['level'] as num).toDouble(),
                  ),
              ],
            ),
          ),
        'level' => LevelMessage(
            monitorId: json['monitorId'] as String,
            sourceId: json['sourceId'] as String,
            level: (json['level'] as num).toDouble(),
          ),
        'output_level' => OutputLevelMessage(
            monitorId: json['monitorId'] as String,
            level: (json['level'] as num).toDouble(),
          ),
        'monitor_removed' => MonitorRemovedMessage(json['id'] as String),
        'error' => ErrorMessage(
            json['code'] as String,
            json['message'] as String? ?? '',
          ),
        _ => UnknownMessage(json),
      };
    } on TypeError {
      return UnknownMessage(json);
    }
  }
}

Output _decodeOutput(Object? json) {
  final output = json as Map<String, dynamic>;
  return switch (output['status']) {
    'ok' => Output(OutputStatus.ok, (output['level'] as num).toDouble()),
    'missing' => const Output(OutputStatus.missing),
    'multiple' => const Output(OutputStatus.multiple),
    _ => throw TypeError(),
  };
}

class WelcomeMessage extends ServerMessage {
  const WelcomeMessage(this.protocolVersion);
  final int protocolVersion;
}

class MonitorsMessage extends ServerMessage {
  const MonitorsMessage(this.monitors);
  final List<Monitor> monitors;
}

class MonitorMessage extends ServerMessage {
  const MonitorMessage(this.monitor);
  final MonitorState monitor;
}

/// A source's level changed (in REAPER, from another phone, or the echo of
/// this phone's own set_level).
class LevelMessage extends ServerMessage {
  const LevelMessage({
    required this.monitorId,
    required this.sourceId,
    required this.level,
  });
  final String monitorId;
  final String sourceId;

  /// Linear, 1.0 = 0 dB.
  final double level;
}

/// A monitor's master level changed (in REAPER, from another phone, or the
/// echo of this phone's own set_output_level).
class OutputLevelMessage extends ServerMessage {
  const OutputLevelMessage({required this.monitorId, required this.level});
  final String monitorId;

  /// Linear, 1.0 = 0 dB.
  final double level;
}

/// The subscribed monitor no longer exists; the subscription is over.
class MonitorRemovedMessage extends ServerMessage {
  const MonitorRemovedMessage(this.monitorId);
  final String monitorId;
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.code, this.message);
  final String code;
  final String message;
}

class UnknownMessage extends ServerMessage {
  const UnknownMessage(this.json);
  final Object? json;
}

/// Wire messages of the protocol described in docs/protocol.md.
library;

const int protocolVersion = 1;

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

/// Full state of one monitor: its sources in receive order.
class MonitorState {
  const MonitorState({
    required this.id,
    required this.name,
    required this.sources,
  });

  final String id;
  final String name;
  final List<Source> sources;
}

Map<String, Object?> subscribeMessage(String monitorId) => {
      'type': 'subscribe',
      'monitorId': monitorId,
    };

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

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.code, this.message);
  final String code;
  final String message;
}

class UnknownMessage extends ServerMessage {
  const UnknownMessage(this.json);
  final Object? json;
}

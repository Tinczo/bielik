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

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.code, this.message);
  final String code;
  final String message;
}

class UnknownMessage extends ServerMessage {
  const UnknownMessage(this.json);
  final Object? json;
}

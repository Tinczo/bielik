import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'messages.dart';

/// Why connecting to the extension failed.
enum ConnectionFailure {
  /// Nothing answered, the connection dropped, or the server said something
  /// unexpected.
  network,

  /// The server refused the band password (`bad_password`).
  badPassword,

  /// The server speaks another protocol version (`unsupported_version`).
  unsupportedVersion,
}

/// Thrown when connecting to the extension fails.
class MixerConnectionException implements Exception {
  MixerConnectionException(
    this.message, {
    this.failure = ConnectionFailure.network,
  });
  final String message;
  final ConnectionFailure failure;

  @override
  String toString() => 'MixerConnectionException($failure): $message';
}

/// Client side of the protocol: one WebSocket connection to the REAPER
/// extension. Independent of the UI.
class MixerClient {
  MixerClient._(this._socket) {
    _subscription = _socket.listen(
      _onData,
      onDone: _onDone,
      onError: (_) => _onDone(),
    );
  }

  /// Connects to the extension and completes the hello/welcome handshake.
  /// Throws [MixerConnectionException] telling why it failed.
  static Future<MixerClient> connect({
    required String host,
    required int port,
    String password = '',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final WebSocket socket;
    try {
      socket = await WebSocket.connect('ws://$host:$port/').timeout(timeout);
    } on Object catch (error) {
      throw MixerConnectionException('cannot connect to $host:$port: $error');
    }
    final client = MixerClient._(socket);
    client._send(helloMessage(password: password));
    try {
      await client._welcome.future.timeout(timeout);
    } on TimeoutException {
      await client.close();
      throw MixerConnectionException('no welcome from $host:$port');
    } on Object {
      await client.close();
      rethrow;
    }
    return client;
  }

  final WebSocket _socket;
  late final StreamSubscription<dynamic> _subscription;
  final Completer<void> _welcome = Completer<void>();

  /// Monitors of the active project; null until the server sends the list.
  final ValueNotifier<List<Monitor>?> monitors = ValueNotifier(null);

  /// State of the subscribed monitor; null until the server sends it.
  final ValueNotifier<MonitorState?> monitor = ValueNotifier(null);

  String? _subscribedMonitorId;

  /// Starts showing [monitorId]; replaces any previous subscription.
  void subscribe(String monitorId) {
    _subscribedMonitorId = monitorId;
    monitor.value = null;
    _send(subscribeMessage(monitorId));
  }

  /// Sets the level of a source of the subscribed monitor. The new level shows
  /// in [monitor] at once; the server does not confirm it.
  void setLevel(String sourceId, double level) {
    final current = monitor.value;
    if (current == null) return;
    _send(
      setLevelMessage(monitorId: current.id, sourceId: sourceId, level: level),
    );
    monitor.value = MonitorState(
      id: current.id,
      name: current.name,
      sources: [
        for (final source in current.sources)
          source.id == sourceId
              ? Source(id: source.id, name: source.name, level: level)
              : source,
      ],
    );
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    monitors.dispose();
    monitor.dispose();
  }

  void _send(Map<String, Object?> message) => _socket.add(jsonEncode(message));

  void _onData(dynamic data) {
    if (data is! String) return;
    final Object? json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return;
    }
    switch (ServerMessage.fromJson(json)) {
      case WelcomeMessage():
        if (!_welcome.isCompleted) _welcome.complete();
      case MonitorsMessage(:final monitors):
        this.monitors.value = monitors;
      case MonitorMessage(:final monitor):
        // Ignore a late answer for a monitor the musician has already left.
        if (monitor.id == _subscribedMonitorId) this.monitor.value = monitor;
      case ErrorMessage(:final code, :final message):
        if (!_welcome.isCompleted) {
          _welcome.completeError(
            MixerConnectionException(
              'server refused: $code $message',
              failure: switch (code) {
                'bad_password' => ConnectionFailure.badPassword,
                'unsupported_version' => ConnectionFailure.unsupportedVersion,
                _ => ConnectionFailure.network,
              },
            ),
          );
        } else {
          debugPrint('server error: $code $message');
        }
      case UnknownMessage():
        break;
    }
  }

  void _onDone() {
    if (!_welcome.isCompleted) {
      _welcome.completeError(
        MixerConnectionException('connection closed during handshake'),
      );
    }
  }
}

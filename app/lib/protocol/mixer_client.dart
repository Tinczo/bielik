import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'messages.dart';

/// Thrown when connecting to the extension fails.
class MixerConnectionException implements Exception {
  MixerConnectionException(this.message);
  final String message;

  @override
  String toString() => 'MixerConnectionException: $message';
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
  static Future<MixerClient> connect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final WebSocket socket;
    try {
      socket = await WebSocket.connect('ws://$host:$port/').timeout(timeout);
    } on Object catch (error) {
      throw MixerConnectionException('cannot connect to $host:$port: $error');
    }
    final client = MixerClient._(socket);
    client._send(helloMessage());
    try {
      await client._welcome.future.timeout(timeout);
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

  final StreamController<String> _monitorRemoved =
      StreamController<String>.broadcast();

  /// Ids of subscribed monitors that were removed in REAPER (track deleted,
  /// renamed without the prefix, another project opened). The subscription
  /// ends with them.
  Stream<String> get monitorRemoved => _monitorRemoved.stream;

  String? _subscribedMonitorId;

  /// Starts showing [monitorId]; replaces any previous subscription.
  void subscribe(String monitorId) {
    _subscribedMonitorId = monitorId;
    monitor.value = null;
    _send(subscribeMessage(monitorId));
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    monitors.dispose();
    monitor.dispose();
    await _monitorRemoved.close();
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
      case MonitorRemovedMessage(:final monitorId):
        if (monitorId != _subscribedMonitorId) return;
        _subscribedMonitorId = null;
        monitor.value = null;
        _monitorRemoved.add(monitorId);
      case ErrorMessage(:final code, :final message):
        if (!_welcome.isCompleted) {
          _welcome.completeError(
            MixerConnectionException('server refused: $code $message'),
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

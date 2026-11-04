import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

/// Whether a [MixerClient] can talk to the extension right now.
enum ConnectionStatus {
  /// Handshake done; level changes reach REAPER.
  connected,

  /// The connection dropped; the client is trying to get it back. Controls
  /// that change levels should be disabled meanwhile.
  reconnecting,
}

/// Client side of the protocol: a connection to the REAPER extension that
/// comes back on its own after a Wi-Fi drop or a REAPER restart (retrying with
/// a growing delay, then subscribing to the same monitor again). Independent
/// of the UI.
class MixerClient {
  MixerClient._(
    this.host,
    this.port,
    this.password,
    this._timeout,
    this._keepAlive,
  );

  /// Connects to the extension and completes the hello/welcome handshake.
  /// Throws [MixerConnectionException] telling why it failed.
  ///
  /// With [keepAlive] the client pings the server at that interval and treats
  /// a missing pong as a dropped connection, so a vanished Wi-Fi is noticed
  /// even when no TCP close arrives.
  static Future<MixerClient> connect({
    required String host,
    required int port,
    String password = '',
    Duration timeout = const Duration(seconds: 5),
    Duration? keepAlive,
  }) async {
    final client = MixerClient._(host, port, password, timeout, keepAlive);
    await client._open();
    return client;
  }

  /// Delay before the first reconnect attempt; it doubles up to the maximum.
  static const _firstRetryDelay = Duration(milliseconds: 500);
  static const _maxRetryDelay = Duration(seconds: 5);

  final String host;
  final int port;
  final String password;
  final Duration _timeout;
  final Duration? _keepAlive;

  WebSocket? _socket;

  /// The socket whose handshake succeeded; only its loss triggers reconnecting.
  WebSocket? _established;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _welcome;
  Timer? _retryTimer;
  Duration _retryDelay = _firstRetryDelay;
  bool _closed = false;

  /// Whether the extension can be reached right now.
  final ValueNotifier<ConnectionStatus> connection = ValueNotifier(
    ConnectionStatus.connected,
  );

  /// Monitors of the active project; null until the server sends the list.
  /// Kept while reconnecting.
  final ValueNotifier<List<Monitor>?> monitors = ValueNotifier(null);

  /// State of the subscribed monitor; null until the server sends it. Kept
  /// while reconnecting.
  final ValueNotifier<MonitorState?> monitor = ValueNotifier(null);

  final StreamController<String> _monitorRemoved =
      StreamController<String>.broadcast();

  /// Ids of subscribed monitors that were removed in REAPER (track deleted,
  /// renamed without the prefix, another project opened). The subscription
  /// ends with them.
  Stream<String> get monitorRemoved => _monitorRemoved.stream;

  String? _subscribedMonitorId;

  /// Set while reconnecting: the next monitor list decides whether to
  /// subscribe again.
  bool _resubscribeOnMonitors = false;

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
    _closed = true;
    _retryTimer?.cancel();
    await _dropSocket();
    connection.dispose();
    monitors.dispose();
    monitor.dispose();
    await _monitorRemoved.close();
  }

  /// Opens a socket and completes the handshake on it.
  Future<void> _open() async {
    final WebSocket socket;
    try {
      socket = await WebSocket.connect('ws://$host:$port/').timeout(_timeout);
    } on Object catch (error) {
      throw MixerConnectionException('cannot connect to $host:$port: $error');
    }
    if (_closed) {
      await socket.close();
      throw MixerConnectionException('client closed');
    }
    socket.pingInterval = _keepAlive;
    final welcome = Completer<void>();
    _socket = socket;
    _welcome = welcome;
    _subscription = socket.listen(
      _onData,
      onDone: () => _onDone(socket),
      onError: (_) => _onDone(socket),
    );
    _send(helloMessage(password: password));
    try {
      await welcome.future.timeout(_timeout);
    } on TimeoutException {
      await _dropSocket();
      throw MixerConnectionException('no welcome from $host:$port');
    } on Object {
      await _dropSocket();
      rethrow;
    }
    _established = socket;
  }

  Future<void> _dropSocket() async {
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
  }

  void _send(Map<String, Object?> message) => _socket?.add(jsonEncode(message));

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
        if (_welcome case final welcome? when !welcome.isCompleted) {
          welcome.complete();
        }
      case MonitorsMessage(:final monitors):
        this.monitors.value = monitors;
        if (_resubscribeOnMonitors) {
          _resubscribeOnMonitors = false;
          _resubscribe(monitors);
        }
      case MonitorMessage(:final monitor):
        // Ignore a late answer for a monitor the musician has already left.
        if (monitor.id == _subscribedMonitorId) this.monitor.value = monitor;
      case MonitorRemovedMessage(:final monitorId):
        if (monitorId == _subscribedMonitorId) _endSubscription();
      case ErrorMessage(:final code, :final message):
        if (_welcome case final welcome? when !welcome.isCompleted) {
          welcome.completeError(
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

  void _endSubscription() {
    final monitorId = _subscribedMonitorId!;
    _subscribedMonitorId = null;
    monitor.value = null;
    _monitorRemoved.add(monitorId);
  }

  /// After reconnecting: subscribes to the same monitor again, or ends the
  /// subscription if the monitor is gone (e.g. REAPER came back with another
  /// project).
  void _resubscribe(List<Monitor> monitors) {
    final monitorId = _subscribedMonitorId;
    if (monitorId == null) return;
    if (monitors.any((monitor) => monitor.id == monitorId)) {
      // Keep showing the old state until the fresh one arrives.
      _send(subscribeMessage(monitorId));
    } else {
      _endSubscription();
    }
  }

  void _onDone(WebSocket socket) {
    if (socket != _socket) return; // an old socket, already replaced
    final welcome = _welcome;
    if (welcome != null && !welcome.isCompleted) {
      welcome.completeError(
        MixerConnectionException('connection closed during handshake'),
      );
    }
    if (socket != _established) return; // _open() reports the failure
    _socket = null;
    _subscription = null;
    if (_closed) return;
    connection.value = ConnectionStatus.reconnecting;
    _retryDelay = _firstRetryDelay;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer = Timer(_retryDelay, _retry);
    _retryDelay = Duration(
      milliseconds: min(
        _retryDelay.inMilliseconds * 2,
        _maxRetryDelay.inMilliseconds,
      ),
    );
  }

  Future<void> _retry() async {
    if (_closed) return;
    // The server sends the monitor list right after welcome.
    _resubscribeOnMonitors = true;
    try {
      await _open();
    } on MixerConnectionException {
      if (!_closed) _scheduleRetry();
      return;
    }
    if (_closed) return;
    connection.value = ConnectionStatus.connected;
  }
}

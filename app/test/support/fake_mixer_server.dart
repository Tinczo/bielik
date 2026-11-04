import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol_examples.dart';

/// In-process stand-in for the REAPER extension. For every connection it plays
/// the server's side of a shared protocol example: it waits for each `client`
/// step (checking that the app sent a matching message) and sends each
/// `server` step, and closes the connection at a `closed` step. At a `project`
/// step (a change in REAPER) it waits until the test calls [changeProject].
/// Mismatches are collected in [problems]. Whatever the app sends after the
/// last step is collected in [extraMessages].
class FakeMixerServer {
  FakeMixerServer._(this._server, this.example) {
    _server.listen(_onRequest);
  }

  /// Listens on loopback; on [port] if given (e.g. to come back after
  /// [close], like a restarted REAPER), otherwise on a free one.
  static Future<FakeMixerServer> start(
    ProtocolExample example, {
    int port = 0,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    return FakeMixerServer._(server, example);
  }

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  /// The example played for each new connection; may be swapped mid-test.
  ProtocolExample example;

  /// Everything that did not go according to the example.
  final List<String> problems = [];

  /// How many connections the server has accepted.
  int connections = 0;

  /// Decoded messages the app sent after the example's last step, in order.
  final List<Map<String, dynamic>> extraMessages = [];

  int _projectChangesAllowed = 0;
  final StreamController<void> _projectChanged =
      StreamController<void>.broadcast();

  /// Lets the example go past its next `project` step: the project changes in
  /// REAPER and the server sends what follows.
  void changeProject() {
    _projectChangesAllowed++;
    _projectChanged.add(null);
  }

  /// False when the server closed first.
  Future<bool> _waitForProjectChange() async {
    while (_projectChangesAllowed == 0) {
      if (_projectChanged.isClosed) return false;
      try {
        await _projectChanged.stream.first;
      } on StateError {
        return false; // closed while waiting
      }
    }
    _projectChangesAllowed--;
    return true;
  }

  String get host => _server.address.address;
  int get port => _server.port;

  /// Cuts every open connection (like a Wi-Fi drop) but keeps listening.
  Future<void> dropConnections() async {
    final sockets = [..._sockets];
    _sockets.clear();
    for (final socket in sockets) {
      await socket.close();
    }
  }

  Future<void> close() async {
    await dropConnections();
    await _server.close(force: true);
    await _projectChanged.close();
  }

  Future<void> _onRequest(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    connections++;
    final incoming = StreamIterator<dynamic>(socket);
    for (final step in example.steps) {
      if (step.containsKey('project')) {
        if (!await _waitForProjectChange()) return;
        continue;
      }
      if (step['closed'] == true) {
        await socket.close();
        return;
      }
      if (step.containsKey('server')) {
        socket.add(jsonEncode(step['server']));
        continue;
      }
      if (!await incoming.moveNext()) {
        if (_sockets.contains(socket)) {
          problems.add(
            'connection closed, expected ${jsonEncode(step['client'])}',
          );
        }
        return;
      }
      final received = jsonDecode(incoming.current as String);
      if (!matchesExample(step['client'], received)) {
        problems.add(
          'expected ${jsonEncode(step['client'])}, got ${jsonEncode(received)}',
        );
      }
    }
    while (await incoming.moveNext()) {
      extraMessages.add(
        jsonDecode(incoming.current as String) as Map<String, dynamic>,
      );
    }
  }
}

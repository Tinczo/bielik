import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol_examples.dart';

/// In-process stand-in for the REAPER extension. For every connection it plays
/// the server's side of a shared protocol example: it waits for each `client`
/// step (checking that the app sent a matching message) and sends each
/// `server` step. Mismatches are collected in [problems]. Whatever the app sends
/// after the last step is collected in [extraMessages].
class FakeMixerServer {
  FakeMixerServer._(this._server, this._example) {
    _server.listen(_onRequest);
  }

  static Future<FakeMixerServer> start(ProtocolExample example) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeMixerServer._(server, example);
  }

  final HttpServer _server;
  final ProtocolExample _example;
  final List<WebSocket> _sockets = [];

  /// Everything that did not go according to the example.
  final List<String> problems = [];

  /// Decoded messages the app sent after the example's last step, in order.
  final List<Map<String, dynamic>> extraMessages = [];

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }

  Future<void> _onRequest(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    final incoming = StreamIterator<dynamic>(socket);
    for (final step in _example.steps) {
      if (step.containsKey('server')) {
        socket.add(jsonEncode(step['server']));
        continue;
      }
      if (!await incoming.moveNext()) {
        problems.add('connection closed, expected ${jsonEncode(step['client'])}');
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

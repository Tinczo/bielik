import 'package:flutter/material.dart';

import '../discovery/laptop_discovery.dart';
import '../platform/screen_wake_lock.dart';
import '../protocol/mixer_client.dart';
import '../storage/password_store.dart';
import '../storage/session_store.dart';
import 'connection_status_bar.dart';
import 'discovered_laptops.dart';
import 'monitors_screen.dart';

/// Default port of the REAPER extension (docs/protocol.md).
const int defaultPort = 8790;

/// Connection screen: the band password (remembered after a successful
/// connection), laptops discovered on the network, plus a manual address as
/// the fallback when the network blocks multicast. On start it goes back to
/// the last server (and its last monitor) by itself.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.passwordStore,
    required this.sessionStore,
    required this.screenWakeLock,
    this.discovery,
    this.keepAlive,
  });

  final PasswordStore passwordStore;
  final SessionStore sessionStore;
  final ScreenWakeLock screenWakeLock;
  final LaptopDiscovery? discovery;
  final Duration? keepAlive;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '$defaultPort');
  final _password = TextEditingController();
  bool _connecting = false;
  String? _error;

  /// What was remembered at start, until a connection succeeds: the monitor
  /// is reopened once, also when the first attempt failed and the musician
  /// connects to that laptop by hand.
  LastSession? _restored;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Fills in what was remembered and reconnects to the last server.
  Future<void> _restore() async {
    await _loadPassword();
    final LastSession? session;
    try {
      session = await widget.sessionStore.read();
    } catch (_) {
      return; // nothing remembered we can use; the musician connects by hand
    }
    if (!mounted || session == null || _connecting) return;
    _restored = session;
    _host.text = session.host;
    _port.text = '${session.port}';
    await _connectTo(session.host, session.port);
  }

  Future<void> _loadPassword() async {
    final String? password;
    try {
      password = await widget.passwordStore.read();
    } on Exception {
      return; // nothing remembered we can use; the musician types it
    }
    if (mounted && password != null && _password.text.isEmpty) {
      _password.text = password;
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || port == null) {
      setState(() => _error = 'Podaj adres i port laptopa.');
      return;
    }
    await _connectTo(host, port);
  }

  String _describe(ConnectionFailure failure, String host, int port) =>
      switch (failure) {
        ConnectionFailure.badPassword =>
          'Złe hasło. Zapytaj zespół o aktualne hasło.',
        ConnectionFailure.unsupportedVersion =>
          'Rozszerzenie w REAPERze ma inną wersję niż Bielik. '
              'Zaktualizuj Rozszerzenie albo Bielika.',
        ConnectionFailure.network => 'Nie udało się połączyć z $host:$port.',
      };

  Future<void> _connectTo(String host, int port) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final password = _password.text;
    try {
      final client = await MixerClient.connect(
        host: host,
        port: port,
        password: password,
        keepAlive: widget.keepAlive,
      );
      try {
        await widget.passwordStore.write(password);
      } on Exception {
        // Not remembered this time; the connection itself is fine.
      }
      await rememberLaptop(widget.sessionStore, host, port);
      if (!mounted) {
        await client.close();
        return;
      }
      final restored = _restored;
      _restored = null;
      // Refused while reconnecting: only this screen can fix that.
      client.connection.addListener(() {
        if (client.connection.value == ConnectionStatus.refused && mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConnectionStatusBar(
            client: client,
            child: MonitorsScreen(
              client: client,
              sessionStore: widget.sessionStore,
              screenWakeLock: widget.screenWakeLock,
              reopenMonitorId: restored != null && restored.isFor(host, port)
                  ? restored.monitorId
                  : null,
            ),
          ),
        ),
      );
      final refusal = client.refusal;
      await client.close();
      if (refusal != null && mounted) {
        setState(() => _error = _describe(refusal, host, port));
      }
    } on MixerConnectionException catch (error) {
      if (mounted) {
        setState(() => _error = _describe(error.failure, host, port));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bielik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('password'),
            controller: _password,
            decoration: const InputDecoration(labelText: 'Hasło zespołu'),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
          ),
          const SizedBox(height: 16),
          if (widget.discovery case final discovery?) ...[
            DiscoveredLaptops(
              discovery: discovery,
              enabled: !_connecting,
              onSelected: (laptop) => _connectTo(laptop.host, laptop.port),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('host'),
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Adres laptopa',
              hintText: 'np. 192.168.1.20',
            ),
            keyboardType: TextInputType.url,
          ),
          TextField(
            key: const Key('port'),
            controller: _port,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _connecting ? null : _connect,
            child: const Text('Połącz'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

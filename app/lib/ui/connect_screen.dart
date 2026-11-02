import 'package:flutter/material.dart';

import '../protocol/mixer_client.dart';
import '../storage/password_store.dart';
import 'monitors_screen.dart';

/// Default port of the REAPER extension (docs/protocol.md).
const int defaultPort = 8790;

/// Manual address entry: the musician types the laptop's address and port,
/// and the band password, which Bielik remembers after a successful connection.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.passwordStore});

  final PasswordStore passwordStore;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '$defaultPort');
  final _password = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final password = await widget.passwordStore.read();
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
      );
      await widget.passwordStore.write(password);
      if (!mounted) {
        await client.close();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MonitorsScreen(client: client),
        ),
      );
      await client.close();
    } on MixerConnectionException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.failure) {
            ConnectionFailure.badPassword =>
              'Złe hasło. Zapytaj zespół o aktualne hasło.',
            ConnectionFailure.unsupportedVersion =>
              'Rozszerzenie w REAPERze ma inną wersję niż Bielik. '
                  'Zaktualizuj Rozszerzenie albo Bielika.',
            ConnectionFailure.network =>
              'Nie udało się połączyć z $host:$port.',
          },
        );
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
          TextField(
            key: const Key('password'),
            controller: _password,
            decoration: const InputDecoration(labelText: 'Hasło zespołu'),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
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

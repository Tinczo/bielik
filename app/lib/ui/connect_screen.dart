import 'package:flutter/material.dart';

import '../protocol/mixer_client.dart';
import 'monitors_screen.dart';

/// Default port of the REAPER extension (docs/protocol.md).
const int defaultPort = 8790;

/// Manual address entry: the musician types the laptop's address and port.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '$defaultPort');
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
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
    try {
      final client = await MixerClient.connect(host: host, port: port);
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
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Nie udało się połączyć z $host:$port.');
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

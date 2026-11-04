import 'package:flutter/material.dart';

import '../protocol/mixer_client.dart';

/// Wraps a screen that talks to the extension and shows under it a bar telling
/// the musician that the connection dropped and Bielik is reconnecting.
///
/// Controls that change levels should also read [MixerClient.connection] and
/// disable themselves unless it is [ConnectionStatus.connected].
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({
    super.key,
    required this.client,
    required this.child,
  });

  final MixerClient client;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(child: child),
        ValueListenableBuilder<ConnectionStatus>(
          valueListenable: client.connection,
          builder: (context, status, _) {
            if (status != ConnectionStatus.reconnecting) {
              return const SizedBox.shrink();
            }
            return Material(
              color: colors.errorContainer,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: colors.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rozłączono. Łączę ponownie…',
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

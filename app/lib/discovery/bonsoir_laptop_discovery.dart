import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'laptop_discovery.dart';

/// mDNS service type the REAPER extension announces (docs/protocol.md).
const String mixerServiceType = '_reaper-mixer._tcp';

/// Real discovery over mDNS/DNS-SD (Android NSD through the bonsoir package).
/// Not covered by automated tests; tests use a fake [LaptopDiscovery].
class BonsoirLaptopDiscovery implements LaptopDiscovery {
  @override
  Stream<List<DiscoveredLaptop>> laptops() {
    late StreamController<List<DiscoveredLaptop>> controller;
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? events;
    final found = <String, DiscoveredLaptop>{};

    void publish() => controller.add(List.unmodifiable(found.values));

    Future<void> start() async {
      try {
        final d = discovery = BonsoirDiscovery(type: mixerServiceType);
        await d.initialize();
        events = d.eventStream!.listen((event) {
          switch (event) {
            case BonsoirDiscoveryServiceFoundEvent(:final service):
              service.resolve(d.serviceResolver);
            case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
                  BonsoirDiscoveryServiceUpdatedEvent(:final service):
              final laptop = _toLaptop(service);
              if (laptop != null) {
                found[service.name] = laptop;
                publish();
              }
            case BonsoirDiscoveryServiceLostEvent(:final service):
              if (found.remove(service.name) != null) publish();
            default:
              break;
          }
        }, onError: controller.addError);
        await d.start();
      } catch (error, stack) {
        controller.addError(error, stack);
      }
    }

    controller = StreamController<List<DiscoveredLaptop>>(
      onListen: start,
      onCancel: () async {
        await events?.cancel();
        try {
          await discovery?.stop();
        } catch (_) {
          // Already stopped or never started: nothing to release.
        }
      },
    );
    return controller.stream;
  }

  static DiscoveredLaptop? _toLaptop(BonsoirService service) {
    final addresses = service.hostAddresses;
    final host = addresses.firstWhere(
      (a) => !a.contains(':'), // prefer IPv4: simplest to put in a ws:// URL
      orElse: () => addresses.firstOrNull ?? service.hostname ?? '',
    );
    if (host.isEmpty || service.port <= 0) return null;
    return DiscoveredLaptop(name: service.name, host: host, port: service.port);
  }
}

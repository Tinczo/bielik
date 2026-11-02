/// A laptop running the REAPER extension, found on the local network.
class DiscoveredLaptop {
  const DiscoveredLaptop({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Computer name the extension announces.
  final String name;
  final String host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredLaptop &&
      other.name == name &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(name, host, port);
}

/// Finds laptops announcing the extension's service on the local network.
abstract interface class LaptopDiscovery {
  /// Every laptop currently visible; emits the whole list on every change.
  /// Discovery runs while the stream is listened to. Emits an error when
  /// discovery cannot work (e.g. the network blocks multicast).
  Stream<List<DiscoveredLaptop>> laptops();
}

import 'dart:async';

import 'package:bielik/discovery/laptop_discovery.dart';

/// Discovery results under the test's control.
class FakeLaptopDiscovery implements LaptopDiscovery {
  final _results = StreamController<List<DiscoveredLaptop>>.broadcast();

  void found(List<DiscoveredLaptop> laptops) => _results.add(laptops);
  void fails() => _results.addError(Exception('multicast blocked'));

  @override
  Stream<List<DiscoveredLaptop>> laptops() => _results.stream;
}

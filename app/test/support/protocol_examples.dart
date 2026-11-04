import 'dart:convert';
import 'dart:io';

/// A shared example exchange from `protocol/examples` (format: docs/protocol.md).
class ProtocolExample {
  ProtocolExample(this.name, this.json);

  final String name;
  final Map<String, dynamic> json;

  List<Map<String, dynamic>> get steps =>
      (json['steps'] as List).cast<Map<String, dynamic>>();

  /// Messages the server sends in this example, in order.
  Iterable<Map<String, dynamic>> get serverMessages => steps
      .where((step) => step.containsKey('server'))
      .map((step) => step['server'] as Map<String, dynamic>);
}

/// `flutter test` runs with the app package as the working directory.
final Directory protocolExamplesDir = Directory('../protocol/examples');

List<ProtocolExample> loadProtocolExamples() {
  final files = protocolExamplesDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      ProtocolExample(
        file.uri.pathSegments.last,
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      ),
  ];
}

ProtocolExample loadProtocolExample(String name) =>
    loadProtocolExamples().singleWhere((example) => example.name == name);

/// The protocol's matching rule: every field of [expected] is present and equal
/// in [actual]; objects may carry extra fields, arrays match element by element.
bool matchesExample(Object? expected, Object? actual) {
  if (expected is Map) {
    return actual is Map &&
        expected.entries.every(
          (entry) =>
              actual.containsKey(entry.key) &&
              matchesExample(entry.value, actual[entry.key]),
        );
  }
  if (expected is List) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (!matchesExample(expected[i], actual[i])) return false;
    }
    return true;
  }
  return expected == actual;
}

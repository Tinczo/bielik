import 'package:bielik/storage/session_store.dart';

/// Stand-in for the app's preferences.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  LastSession? session;

  @override
  Future<LastSession?> read() async => session;

  @override
  Future<void> write(LastSession session) async => this.session = session;
}

import 'package:shared_preferences/shared_preferences.dart';

/// Where the musician was when Bielik last ran: the server and, if one was
/// open, the monitor.
class LastSession {
  const LastSession({required this.host, required this.port, this.monitorId});

  final String host;
  final int port;

  /// GUID of the monitor last opened on this server; null if none.
  final String? monitorId;

  /// Whether this session is about the laptop at [host]:[port].
  bool isFor(String host, int port) => this.host == host && this.port == port;
}

/// Where Bielik keeps the last session between launches.
abstract interface class SessionStore {
  Future<LastSession?> read();
  Future<void> write(LastSession session);
}

/// The app's preferences on the phone.
class PreferencesSessionStore implements SessionStore {
  const PreferencesSessionStore();

  static const _host = 'last_host';
  static const _port = 'last_port';
  static const _monitor = 'last_monitor_id';

  @override
  Future<LastSession?> read() async {
    final preferences = SharedPreferencesAsync();
    final host = await preferences.getString(_host);
    final port = await preferences.getInt(_port);
    if (host == null || port == null) return null;
    return LastSession(
      host: host,
      port: port,
      monitorId: await preferences.getString(_monitor),
    );
  }

  @override
  Future<void> write(LastSession session) async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(_host, session.host);
    await preferences.setInt(_port, session.port);
    if (session.monitorId case final monitorId?) {
      await preferences.setString(_monitor, monitorId);
    } else {
      await preferences.remove(_monitor);
    }
  }
}

/// Writes [session], ignoring a store that fails: not being remembered must
/// not break the connection.
Future<void> rememberSession(SessionStore store, LastSession session) async {
  try {
    await store.write(session);
  } catch (_) {
    // Not remembered this time.
  }
}

/// Remembers the laptop just connected to, before any monitor is opened. The
/// monitor remembered for that same laptop stays; one remembered for another
/// laptop means nothing here and is dropped.
Future<void> rememberLaptop(SessionStore store, String host, int port) async {
  LastSession? last;
  try {
    last = await store.read();
  } catch (_) {
    // Nothing remembered we can use.
  }
  await rememberSession(
    store,
    LastSession(
      host: host,
      port: port,
      monitorId: last != null && last.isFor(host, port) ? last.monitorId : null,
    ),
  );
}

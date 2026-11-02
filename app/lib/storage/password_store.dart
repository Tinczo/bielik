import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where Bielik keeps the band password between rehearsals.
abstract interface class PasswordStore {
  Future<String?> read();
  Future<void> write(String password);
}

/// Android's secure storage (Keystore-backed).
class SecurePasswordStore implements PasswordStore {
  const SecurePasswordStore();

  static const _key = 'band_password';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String password) =>
      _storage.write(key: _key, value: password);
}

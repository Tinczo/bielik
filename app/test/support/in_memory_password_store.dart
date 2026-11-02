import 'package:bielik/storage/password_store.dart';

/// Stand-in for Android's secure storage.
class InMemoryPasswordStore implements PasswordStore {
  InMemoryPasswordStore([this.password]);

  String? password;

  @override
  Future<String?> read() async => password;

  @override
  Future<void> write(String password) async => this.password = password;
}

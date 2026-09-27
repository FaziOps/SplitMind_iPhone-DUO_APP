import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the app-issued bearer token. This is a user session token for our
/// own backend, never an AI provider key (NFR-2, NFR-4).
abstract class AuthTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain-backed store.
class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'splitmind.auth_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryAuthTokenStore implements AuthTokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

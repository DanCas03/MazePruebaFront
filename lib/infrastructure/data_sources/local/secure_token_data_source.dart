import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Acceso raw al almacenamiento seguro del token (Keychain en iOS,
/// EncryptedSharedPreferences/Keystore en Android).
///
/// Patrón Petros Efthymiou: el DataSource encapsula el acceso directo a la
/// librería de persistencia (flutter_secure_storage). El Repository depende de
/// esta clase y no del plugin, lo que permite mockear el DataSource y testear
/// el Repository de forma aislada — igual que HiveLocalDataSource.
class SecureTokenDataSource {
  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  SecureTokenDataSource(this._storage);

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> delete() => _storage.delete(key: _tokenKey);
}

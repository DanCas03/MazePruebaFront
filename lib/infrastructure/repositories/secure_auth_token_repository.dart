import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../data_sources/local/secure_token_data_source.dart';

/// Adapter: implementa el puerto IAuthTokenStorage mapeando el Value Object
/// AuthToken a/desde el String crudo a través del DataSource. Nunca toca
/// flutter_secure_storage directamente (DIP + regla de dependencias
/// infraestructura -> dominio), igual que HiveProgressRepository.
class SecureAuthTokenRepository implements IAuthTokenStorage {
  final SecureTokenDataSource _dataSource;
  SecureAuthTokenRepository(this._dataSource);

  @override
  Future<void> save(AuthToken token) => _dataSource.write(token.value);

  @override
  Future<AuthToken?> read() async {
    final raw = await _dataSource.read();
    // Un valor ausente o vacío no es un token: no reventar AuthToken.
    if (raw == null || raw.isEmpty) return null;
    return AuthToken(raw);
  }

  @override
  Future<void> clear() => _dataSource.delete();
}

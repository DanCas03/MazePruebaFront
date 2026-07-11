import 'package:hive_ce/hive.dart';

/// Acceso raw a la box Hive `levels_cache` (patrón Petros: DataSource separado
/// del Repository, mockeable en los tests del repo). Persiste el JSON CRUDO de
/// cada nivel (no un modelo tipado): el decoder es la única fuente de verdad del
/// parseo, sin TypeAdapter que mantener. Sin TTL: online siempre refetchea
/// (network-first). La box se abre en el arranque (main); esta clase la obtiene
/// del registro de Hive.
class LevelCacheDataSource {
  static const boxName = 'levels_cache';
  static const _catalogKey = 'catalog';

  Box get _box => Hive.box(boxName);

  /// Ids del Catálogo en orden, o null si nunca se cacheó.
  List<String>? readCatalog() {
    final raw = _box.get(_catalogKey);
    return raw is List ? raw.cast<String>() : null;
  }

  Future<void> writeCatalog(List<String> ids) => _box.put(_catalogKey, ids);

  /// JSON crudo del nivel [id], o null si no está en caché.
  String? readLevel(String id) {
    final raw = _box.get(_levelKey(id));
    return raw is String ? raw : null;
  }

  Future<void> writeLevel(String id, String rawJson) =>
      _box.put(_levelKey(id), rawJson);

  String _levelKey(String id) => 'level:$id';
}

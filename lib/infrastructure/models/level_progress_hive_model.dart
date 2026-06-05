// lib/infrastructure/models/level_progress_hive_model.dart

import 'package:hive_ce/hive.dart';

import '../../domain/board/entities/level_progress_entry.dart';
import '../../domain/game_core/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';

/// Modelo de persistencia de Hive (Capa 4).
///
/// CLEAN: este modelo usa SOLO primitivos (los tipos que Hive sabe serializar)
/// y es el único punto donde vive el conocimiento de Hive. La conversión
/// hacia/desde la entidad de dominio [LevelProgressEntry] se hace con
/// `toEntry()`/`fromEntry()`, de modo que los Value Objects del dominio
/// ([LevelId], [MoveCount]) NUNCA se filtran a la base de datos.
class LevelProgressHiveModel {
  final int levelId;
  final bool isCompleted;
  final int bestMoveCount;

  const LevelProgressHiveModel({
    required this.levelId,
    required this.isCompleted,
    required this.bestMoveCount,
  });

  /// Mapper: entidad de dominio → modelo de persistencia (extrae primitivos).
  factory LevelProgressHiveModel.fromEntry(LevelProgressEntry entry) {
    return LevelProgressHiveModel(
      levelId: entry.levelId.value,
      isCompleted: entry.isCompleted,
      bestMoveCount: entry.bestMoveCount.value,
    );
  }

  /// Mapper: modelo de persistencia → entidad de dominio (reconstruye VOs).
  LevelProgressEntry toEntry() {
    return LevelProgressEntry(
      levelId: LevelId(levelId),
      isCompleted: isCompleted,
      bestMoveCount: MoveCount(bestMoveCount),
    );
  }
}

/// TypeAdapter manual para [LevelProgressHiveModel].
///
/// Se implementa a mano (en vez de generarlo con build_runner) para que el
/// proyecto compile sin un paso de code-gen. El formato binario es idéntico al
/// que produciría `hive_ce_generator`.
class LevelProgressHiveModelAdapter extends TypeAdapter<LevelProgressHiveModel> {
  @override
  final int typeId = 0;

  @override
  LevelProgressHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LevelProgressHiveModel(
      levelId: fields[0] as int,
      isCompleted: fields[1] as bool,
      bestMoveCount: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LevelProgressHiveModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.levelId)
      ..writeByte(1)
      ..write(obj.isCompleted)
      ..writeByte(2)
      ..write(obj.bestMoveCount);
  }
}

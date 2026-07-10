// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'level_progress_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LevelProgressHiveModelAdapter
    extends TypeAdapter<LevelProgressHiveModel> {
  @override
  final typeId = 0;

  @override
  LevelProgressHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LevelProgressHiveModel(
      levelId: fields[0] as String,
      moveCount: (fields[1] as num).toInt(),
      completed: fields[2] as bool,
      bestScore: (fields[3] as num?)?.toInt(),
      bestStars: (fields[4] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, LevelProgressHiveModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.levelId)
      ..writeByte(1)
      ..write(obj.moveCount)
      ..writeByte(2)
      ..write(obj.completed)
      ..writeByte(3)
      ..write(obj.bestScore)
      ..writeByte(4)
      ..write(obj.bestStars);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelProgressHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

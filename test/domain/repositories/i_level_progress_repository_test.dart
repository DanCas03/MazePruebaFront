import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';

/// Fake en memoria que implementa el puerto: verifica que el contrato es
/// sustituible (LSP) y que la superficie de la interfaz compila como se espera.
class _InMemoryLevelProgressRepository implements ILevelProgressRepository {
  final Map<String, MoveCount> _progress = {};
  final Set<String> _completed = {};
  final Map<String, LevelProgress> _all = {};

  @override
  Future<MoveCount?> getProgress(LevelId levelId) async => _progress[levelId.value];

  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) async {
    _progress[levelId.value] = moves;
  }

  @override
  Future<void> markCompleted(LevelId levelId) async {
    _completed.add(levelId.value);
  }

  @override
  Future<bool> isCompleted(LevelId levelId) async => _completed.contains(levelId.value);

  @override
  Future<List<LevelProgress>> getAll() async => _all.values.toList();

  @override
  Future<void> upsertAll(List<LevelProgress> progress) async {
    for (final p in progress) {
      _all[p.levelId.value] = p;
    }
  }
}

void main() {
  group('ILevelProgressRepository contract', () {
    late ILevelProgressRepository sut;
    final levelId = LevelId('level-1');

    setUp(() {
      sut = _InMemoryLevelProgressRepository();
    });

    test('getProgress returns null when no progress saved', () async {
      // Arrange done in setUp
      // Act
      final result = await sut.getProgress(levelId);
      // Assert
      expect(result, isNull);
    });

    test('saveProgress then getProgress returns the saved MoveCount', () async {
      // Arrange
      const moves = MoveCount(5);
      // Act
      await sut.saveProgress(levelId, moves);
      final result = await sut.getProgress(levelId);
      // Assert
      expect(result, moves);
    });

    test('isCompleted returns false before markCompleted', () async {
      // Act
      final result = await sut.isCompleted(levelId);
      // Assert
      expect(result, isFalse);
    });

    test('markCompleted then isCompleted returns true', () async {
      // Act
      await sut.markCompleted(levelId);
      final result = await sut.isCompleted(levelId);
      // Assert
      expect(result, isTrue);
    });
  });
}

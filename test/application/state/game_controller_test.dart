import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/dependency_providers.dart';
import 'package:flutter_arrow_maze/application/providers/game_controller_provider.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level_progress_entry.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Genera SIEMPRE un tablero fresco 3x1: A (col0)→ bloqueada por B (col2)→.
class _FakeGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate(LevelId levelId) => ArrowBoard(
        width: 3,
        height: 1,
        arrows: const [
          Arrow(
            id: ArrowId(0),
            tail: Position(x: 0, y: 0),
            direction: Direction.right,
            length: ArrowLength(1),
            colorIndex: 0,
          ),
          Arrow(
            id: ArrowId(1),
            tail: Position(x: 2, y: 0),
            direction: Direction.right,
            length: ArrowLength(1),
            colorIndex: 1,
          ),
        ],
      );
}

class _FakeProgressRepository implements ILevelProgressRepository {
  final Map<int, LevelProgressEntry> saved = {};

  @override
  Future<LevelProgressEntry?> loadProgress(LevelId levelId) async =>
      saved[levelId.value];

  @override
  Future<void> saveProgress(LevelProgressEntry entry) async {
    saved[entry.levelId.value] = entry;
  }

  @override
  Future<List<LevelProgressEntry>> loadAllProgress() async =>
      saved.values.toList();
}

class _FakeLogger implements ILoggerService {
  @override
  void log(String message, {String? tag}) {}
  @override
  void warn(String message, {String? tag}) {}
  @override
  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {}
}

void main() {
  late _FakeProgressRepository progress;
  late ProviderContainer container;

  setUp(() {
    progress = _FakeProgressRepository();
    container = ProviderContainer(
      overrides: [
        levelGeneratorProvider.overrideWithValue(_FakeGenerator()),
        levelProgressRepositoryProvider.overrideWithValue(progress),
        loggerServiceProvider.overrideWithValue(_FakeLogger()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('loadLevel deja el juego jugando con todas las flechas', () {
    // Arrange
    final notifier = container.read(gameControllerProvider.notifier);

    // Act
    notifier.loadLevel(const LevelId(1));

    // Assert
    final state = container.read(gameControllerProvider);
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).board.remaining, equals(2));
  });

  test('tocar una flecha bloqueada la marca como bloqueada sin sacarla', () {
    // Arrange
    final notifier = container.read(gameControllerProvider.notifier);
    notifier.loadLevel(const LevelId(1));

    // Act
    notifier.onArrowTapped(const ArrowId(0)); // A está bloqueada por B

    // Assert
    final state = container.read(gameControllerProvider) as GamePlaying;
    expect(state.board.remaining, equals(2));
    expect(state.blockedArrow, equals(const ArrowId(0)));
  });

  test('sacar las flechas en orden válido limpia el tablero y guarda progreso',
      () async {
    // Arrange
    final notifier = container.read(gameControllerProvider.notifier);
    notifier.loadLevel(const LevelId(1));

    // Act
    notifier.onArrowTapped(const ArrowId(1)); // B sale
    notifier.onArrowTapped(const ArrowId(0)); // ahora A sale → tablero limpio

    // La victoria se difiere hasta que termina la animación de salida.
    final intermediate = container.read(gameControllerProvider);
    expect(intermediate, isA<GamePlaying>());
    expect((intermediate as GamePlaying).board.remaining, equals(0));

    await Future<void>.delayed(const Duration(milliseconds: 450));

    // Assert
    final state = container.read(gameControllerProvider);
    expect(state, isA<GameWon>());
    expect((state as GameWon).moves.value, equals(2));
    expect(progress.saved[1]?.isCompleted, isTrue);
    expect(progress.saved[1]?.bestMoveCount.value, equals(2));
  });
}

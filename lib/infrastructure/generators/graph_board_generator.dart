// lib/infrastructure/generators/graph_board_generator.dart

import 'dart:math';

import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/game_core/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/arrow_length.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Generador procedural de tableros RESOLUBLES basado en un grafo de
/// dependencias (DAG).
///
/// Idea (construcción inversa): se colocan flechas una a una; cada flecha nueva
/// debe tener su RECORRIDO DE SALIDA libre de las flechas YA colocadas. Esto
/// equivale a construir un grafo dirigido "A bloquea a B" donde cada arista va
/// de una flecha más antigua a una más nueva ⇒ es acíclico (DAG). Por tanto el
/// orden de salida = orden inverso de colocación siempre resuelve el tablero
/// (orden topológico). Un solucionador voraz (Kahn) también lo limpia siempre.
///
/// La generación es determinista: el mismo [LevelId] siembra el mismo `Random`
/// y produce el mismo tablero.
class GraphBoardGenerator implements ILevelGenerator {
  /// Tamaño de la paleta de colores conocida por la UI (para variar colores).
  static const int paletteSize = 8;

  @override
  ArrowBoard generate(LevelId levelId) {
    final rng = Random(levelId.value);
    final size = _sizeForLevel(levelId.value);
    final maxLength = min(4, size - 1);
    final targetCells = (size * size * 0.55).round();
    final maxAttempts = size * size * 30;

    final occupied = <Position>{};
    final arrows = <Arrow>[];
    var attempts = 0;
    var nextId = 0;

    while (occupied.length < targetCells && attempts < maxAttempts) {
      attempts++;
      final candidate = _randomArrow(
        rng: rng,
        id: ArrowId(nextId),
        size: size,
        maxLength: maxLength,
      );

      if (_canPlace(candidate, occupied, size)) {
        arrows.add(candidate);
        occupied.addAll(candidate.cells);
        nextId++;
      }
    }

    return ArrowBoard(width: size, height: size, arrows: arrows);
  }

  /// La flecha cabe (sin solaparse) y su recorrido de salida está libre de las
  /// flechas ya colocadas: condición que garantiza la solubilidad (DAG).
  bool _canPlace(Arrow arrow, Set<Position> occupied, int size) {
    for (final cell in arrow.cells) {
      if (occupied.contains(cell)) return false;
    }
    for (final cell in arrow.exitPath(size, size)) {
      if (occupied.contains(cell)) return false;
    }
    return true;
  }

  Arrow _randomArrow({
    required Random rng,
    required ArrowId id,
    required int size,
    required int maxLength,
  }) {
    final length = 2 + rng.nextInt(maxLength - 1); // 2..maxLength
    final horizontal = rng.nextBool();
    final colorIndex = rng.nextInt(paletteSize);

    if (horizontal) {
      final y = rng.nextInt(size);
      final startCol = rng.nextInt(size - length + 1); // columnas startCol..+len-1
      final goRight = rng.nextBool();
      final tail = goRight
          ? Position(x: startCol, y: y)
          : Position(x: startCol + length - 1, y: y);
      return Arrow(
        id: id,
        tail: tail,
        direction: goRight ? Direction.right : Direction.left,
        length: ArrowLength(length),
        colorIndex: colorIndex,
      );
    } else {
      final x = rng.nextInt(size);
      final startRow = rng.nextInt(size - length + 1);
      final goDown = rng.nextBool();
      final tail = goDown
          ? Position(x: x, y: startRow)
          : Position(x: x, y: startRow + length - 1);
      return Arrow(
        id: id,
        tail: tail,
        direction: goDown ? Direction.down : Direction.up,
        length: ArrowLength(length),
        colorIndex: colorIndex,
      );
    }
  }

  /// Dificultad: el tablero crece lentamente con el número de nivel.
  int _sizeForLevel(int level) => min(5 + (level ~/ 2), 9);
}

// lib/domain/arrows/entities/arrow_board.dart

import '../../game_core/value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';
import 'arrow.dart';

/// Aggregate Root del juego: la cuadrícula con todas las flechas presentes.
///
/// Posee las flechas y centraliza las reglas del tablero (qué celda está
/// ocupada, si una flecha puede salir, alta/baja de flechas). Ninguna capa
/// externa manipula la lista de flechas directamente: lo hace a través de estos
/// métodos, preservando los invariantes del agregado.
class ArrowBoard {
  final int width;
  final int height;
  final List<Arrow> _arrows;

  ArrowBoard({
    required this.width,
    required this.height,
    required List<Arrow> arrows,
  }) : _arrows = List.of(arrows);

  /// Vista inmutable de las flechas presentes.
  List<Arrow> get arrows => List.unmodifiable(_arrows);

  /// Cantidad de flechas que quedan en el tablero.
  int get remaining => _arrows.length;

  /// El tablero se gana cuando no queda ninguna flecha.
  bool get isCleared => _arrows.isEmpty;

  /// Devuelve la flecha que ocupa [position], o `null` si la celda está libre.
  Arrow? arrowAt(Position position) {
    for (final arrow in _arrows) {
      if (arrow.cells.contains(position)) return arrow;
    }
    return null;
  }

  /// Busca una flecha por su identificador.
  Arrow? findById(ArrowId id) {
    for (final arrow in _arrows) {
      if (arrow.id == id) return arrow;
    }
    return null;
  }

  /// Regla central: una flecha puede salir si todas las celdas de su recorrido
  /// de salida están libres de OTRAS flechas (las celdas propias no cuentan,
  /// porque no forman parte del recorrido de salida).
  bool canExit(Arrow arrow) {
    for (final cell in arrow.exitPath(width, height)) {
      if (arrowAt(cell) != null) return false;
    }
    return true;
  }

  /// Saca una flecha del tablero (libera sus celdas).
  void removeArrow(ArrowId id) {
    _arrows.removeWhere((arrow) => arrow.id == id);
  }

  /// Reincorpora una flecha (usado por el deshacer del patrón Command).
  void addArrow(Arrow arrow) {
    _arrows.add(arrow);
  }

  /// Copia profunda del tablero (útil para simulaciones/tests sin mutar el
  /// original).
  ArrowBoard copy() =>
      ArrowBoard(width: width, height: height, arrows: List.of(_arrows));
}

// lib/domain/arrows/entities/arrow.dart

import '../../game_core/value_objects/arrow_id.dart';
import '../../game_core/value_objects/arrow_length.dart';
import '../../game_core/value_objects/direction.dart';
import '../../game_core/value_objects/position.dart';

/// Entidad de dominio: una flecha del rompecabezas.
///
/// Una flecha ocupa [length] celdas consecutivas a lo largo del eje de su
/// [direction] y "sale" del tablero en esa dirección. Se modela de forma
/// paramétrica (cola + dirección + longitud) en lugar de guardar la lista de
/// celdas, lo que simplifica el generador y el cálculo del recorrido de salida.
///
/// Convención: [tail] es la celda trasera (opuesta a la punta). Las celdas
/// avanzan en la dirección de salida; la [head] (punta) es la celda delantera.
///
/// DDD: se construye con Value Objects ([ArrowId], [Position], [Direction],
/// [ArrowLength]); `colorIndex` es un dato puro (índice en una paleta) para que
/// el dominio no dependa de Flutter.
class Arrow {
  final ArrowId id;
  final Position tail;
  final Direction direction;
  final ArrowLength length;
  final int colorIndex;

  const Arrow({
    required this.id,
    required this.tail,
    required this.direction,
    required this.length,
    required this.colorIndex,
  });

  /// Celdas que ocupa la flecha, desde la cola hacia la punta.
  List<Position> get cells => [
        for (var i = 0; i < length.value; i++)
          Position(x: tail.x + direction.dx * i, y: tail.y + direction.dy * i),
      ];

  /// Celda delantera (donde está la punta), por la que la flecha sale primero.
  Position get head => Position(
        x: tail.x + direction.dx * (length.value - 1),
        y: tail.y + direction.dy * (length.value - 1),
      );

  /// Celdas que la flecha debe atravesar para salir del tablero: desde delante
  /// de la punta, en su dirección, hasta cruzar el borde.
  ///
  /// Si alguna de estas celdas está ocupada por OTRA flecha, este movimiento
  /// queda bloqueado.
  List<Position> exitPath(int boardWidth, int boardHeight) {
    final path = <Position>[];
    var p = Position(x: head.x + direction.dx, y: head.y + direction.dy);
    while (p.x >= 0 && p.x < boardWidth && p.y >= 0 && p.y < boardHeight) {
      path.add(p);
      p = Position(x: p.x + direction.dx, y: p.y + direction.dy);
    }
    return path;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Arrow && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

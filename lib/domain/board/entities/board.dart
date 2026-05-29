// lib/domain/entities/board.dart
import 'cell.dart';
import '../../game_core/value_objects/position.dart';

class Board {
  final int width;
  final int height;
  
  // Representamos la cuadrícula como una lista de listas (filas y columnas)
  final List<List<ICell>> grid;

  Board({
    required this.width,
    required this.height,
    required this.grid,
  });

  /// Devuelve la celda en una posición específica.
  /// Retorna nulo si la posición está fuera de los límites del tablero.
  ICell? getCellAt(Position position) {
    if (position.x < 0 || position.x >= width || position.y < 0 || position.y >= height) {
      return null; // El jugador chocó contra el borde del mapa
    }
    // En una matriz 2D típica, el primer índice es la fila (y) y el segundo la columna (x)
    return grid[position.y][position.x];
  }
}
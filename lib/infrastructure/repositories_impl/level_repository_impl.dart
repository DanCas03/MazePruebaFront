import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/board/repositories/i_level_repository.dart';
import '../../domain/board/entities/board.dart';
import '../../domain/board/entities/cell.dart';
import '../../domain/board/factories/cell_factory.dart';
import '../../domain/player/entities/player.dart';
import '../../domain/game_core/value_objects/position.dart';
import '../../domain/game_core/value_objects/direction.dart';

class LevelRepositoryImpl implements ILevelRepository {
  
  @override
  Future<LevelData> loadLevel(int levelId) async {
    // 1. Leemos el archivo físico usando Flutter
    final String jsonString = await rootBundle.loadString('assets/levels/level_$levelId.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    final int width = jsonData['width'];
    final int height = jsonData['height'];
    
    // 2. Preparamos una matriz vacía para el tablero
    List<List<ICell>> grid = List.generate(
      height, 
      (y) => List.filled(width, CellFactory.createCell(type: 'empty', position: Position(x: 0, y: 0))),
    );

    // 3. Poblamos la matriz usando nuestro Patrón Factory
    final List<dynamic> cellsData = jsonData['cells'];
    for (var cellData in cellsData) {
      final int x = cellData['x'];
      final int y = cellData['y'];
      final String type = cellData['type'];
      
      Direction? dir;
      if (cellData.containsKey('direction')) {
        dir = _parseDirection(cellData['direction']);
      }

      // ¡Aquí brilla el Factory Method! No usamos 'new ArrowCell' ni nada concreto.
      grid[y][x] = CellFactory.createCell(
        type: type, 
        position: Position(x: x, y: y),
        initialDirection: dir,
      );
    }

    // 4. Creamos el Tablero
    final board = Board(width: width, height: height, grid: grid);

    // 5. Creamos al Jugador
    final int startX = jsonData['player_start']['x'];
    final int startY = jsonData['player_start']['y'];
    final player = Player(currentPosition: Position(x: startX, y: startY));

    return LevelData(board: board, player: player);
  }

  // Utilidad para parsear el string a nuestro Enum
  Direction _parseDirection(String dirStr) {
    switch (dirStr) {
      case 'up': return Direction.up;
      case 'down': return Direction.down;
      case 'left': return Direction.left;
      case 'right': return Direction.right;
      default: return Direction.up;
    }
  }
}
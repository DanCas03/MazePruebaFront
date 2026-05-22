// lib/presentation/game/widgets/cell_widget.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

// Importaciones de tu Dominio
import '../../../domain/board/entities/cell.dart';
import '../../../domain/board/entities/empty_cell.dart';
import '../../../domain/board/entities/wall_cell.dart';
import '../../../domain/board/entities/arrow_cell.dart';
import '../../../domain/board/entities/exit_cell.dart';
import '../../../domain/board/decorators/locked_cell_decorator.dart';
import '../../../domain/game_core/value_objects/direction.dart';

/// ------------------------------------------------------------------------
/// PARTE 1: EL MAPA DE ESTRATEGIAS (Strategy Pattern)
/// ------------------------------------------------------------------------

/// Firma de nuestra estrategia: Recibe el contexto y la celda, devuelve un Widget
typedef CellRenderer = Widget Function(BuildContext context, ICell cell);

/// Mapa de estrategias visuales. ¡Adiós a los if-else!
final Map<Type, CellRenderer> _renderStrategies = {
  EmptyCell: (context, cell) => Container(
        color: Colors.grey[200],
        margin: const EdgeInsets.all(1.0),
      ),
      
  WallCell: (context, cell) => Container(
        color: Colors.blueGrey[800],
        margin: const EdgeInsets.all(1.0),
        child: const Icon(Icons.grid_3x3, color: Colors.black26),
      ),
      
  ExitCell: (context, cell) => Container(
        color: Colors.green[300],
        margin: const EdgeInsets.all(1.0),
        child: const Icon(Icons.exit_to_app, color: Colors.white, size: 30),
      ),
      
  ArrowCell: (context, cell) {
    final arrow = cell as ArrowCell;
    return Container(
      color: Colors.orange[100],
      margin: const EdgeInsets.all(1.0),
      child: Transform.rotate(
        angle: _getRotationAngle(arrow.currentDirection),
        child: const Icon(Icons.arrow_upward, color: Colors.deepOrange, size: 32),
      ),
    );
  },
};

/// Utilidad matemática para la rotación del ícono de Flutter
double _getRotationAngle(Direction dir) {
  switch (dir) {
    case Direction.up: return 0;
    case Direction.right: return math.pi / 2;     // 90 grados
    case Direction.down: return math.pi;          // 180 grados
    case Direction.left: return 3 * math.pi / 2;  // 270 grados
  }
}

/// ------------------------------------------------------------------------
/// PARTE 2: EL WIDGET PRINCIPAL
/// ------------------------------------------------------------------------

class CellWidget extends StatelessWidget {
  final ICell cell;
  final bool isPlayerHere;

  const CellWidget({
    Key? key,
    required this.cell,
    this.isPlayerHere = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Buscamos el tipo real de la celda (desenvolviendo el decorador si es necesario)
    ICell targetCell = cell;
    bool isLocked = false;

    if (cell is LockedCellDecorator) {
      isLocked = (cell as LockedCellDecorator).isLocked;
      targetCell = (cell as LockedCellDecorator).wrappedCell;
    }

    // 2. Ejecutamos la estrategia visual para esa celda buscando en el Mapa
    final renderer = _renderStrategies[targetCell.runtimeType];
    
    // Si olvidamos registrar una celda, dibujamos un error visible para el desarrollador
    Widget cellUI = renderer != null 
        ? renderer(context, targetCell) 
        : Container(color: Colors.red, child: const Text('?'));

    // 3. Apilamos los elementos (Celda -> Candado -> Jugador)
    return Stack(
      fit: StackFit.expand,
      children: [
        // La celda base dibujada por la estrategia
        cellUI,

        // Si está decorada con un candado, lo dibujamos encima
        if (isLocked)
          const Center(
            child: Icon(Icons.lock, color: Colors.redAccent, size: 20),
          ),

        // Si el jugador está aquí, lo dibujamos en la cima
        if (isPlayerHere)
          Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ),
      ],
    );
  }
}
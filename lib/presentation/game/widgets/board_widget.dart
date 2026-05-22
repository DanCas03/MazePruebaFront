import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'cell_widget.dart';

class BoardWidget extends StatelessWidget {
  final GameController controller;

  const BoardWidget({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final board = controller.board;

    // Usamos ListenableBuilder para escuchar el Patrón Observer
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Evita scroll interno
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: board.width, // Columnas dinámicas según el nivel
          ),
          itemCount: board.width * board.height,
          itemBuilder: (context, index) {
            // Calculamos X e Y a partir del índice del GridView
            final y = index ~/ board.width;
            final x = index % board.width;
            final pos = Position(x: x, y: y);

            // Obtenemos la celda real de nuestra capa de dominio
            final cell = board.getCellAt(pos);
            
            // Verificamos si el jugador está en esta coordenada
            final isPlayerHere = controller.player.currentPosition.x == x &&
                                 controller.player.currentPosition.y == y;

            return GestureDetector(
              onTap: () => controller.onCellTapped(pos),
              child: CellWidget(
                cell: cell,
                isPlayerHere: isPlayerHere,
              ),
            );
          },
        );
      },
    );
  }
}
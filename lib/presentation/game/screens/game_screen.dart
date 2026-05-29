import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../widgets/board_widget.dart';

class GameScreen extends StatelessWidget {
  final GameController controller;

  const GameScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrow Maze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: controller.onUndoPressed,
            tooltip: 'Deshacer',
          ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          final dir = details.primaryVelocity! < 0 ? Direction.up : Direction.down;
          controller.onSwipe(dir);
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          final dir = details.primaryVelocity! < 0 ? Direction.left : Direction.right;
          controller.onSwipe(dir);
        },
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BoardWidget(controller: controller),
                  ),
                ),
                if (controller.isVictory)
                  Container(
                    width: double.infinity,
                    color: Colors.green,
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      '¡Nivel completado!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../presentation/game/screens/game_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/level_selection/level_selection_screen.dart';
import '../../presentation/level_selection/victory_screen.dart';

/// Tabla de rutas nombradas de la app. Centraliza la navegacion (SRP) y
/// desacopla las pantallas entre si: cualquier widget navega por nombre de
/// ruta sin conocer la clase de pantalla destino.
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String levelSelection = '/levels';
  static const String game = '/game';
  static const String victory = '/victory';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRouter.home => _fade(const HomeScreen()),
      AppRouter.levelSelection => _fade(const LevelSelectionScreen()),
      AppRouter.game => _fade(
          GameScreen(
            levelId: settings.arguments is LevelId
                ? settings.arguments as LevelId
                : LevelId('1'),
          ),
        ),
      AppRouter.victory => _fade(const VictoryScreen()),
      _ => _fade(const HomeScreen()),
    };
  }

  static MaterialPageRoute<dynamic> _fade(Widget page) =>
      MaterialPageRoute<dynamic>(builder: (_) => page);
}

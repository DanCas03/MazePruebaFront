import 'package:flutter/material.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../presentation/game/screens/game_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/leaderboard/screens/leaderboard_screen.dart';
import '../../presentation/level_selection/defeat_screen.dart';
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
  static const String defeat = '/defeat';
  static const String leaderboard = '/leaderboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRouter.home => _fade(const HomeScreen(), settings),
      AppRouter.levelSelection => _fade(const LevelSelectionScreen(), settings),
      AppRouter.game => _fade(
          GameScreen(
            levelId: settings.arguments is LevelId
                ? settings.arguments as LevelId
                : LevelId('1'),
          ),
          settings,
        ),
      AppRouter.victory => _fade(const VictoryScreen(), settings),
      AppRouter.defeat => _fade(const DefeatScreen(), settings),
      AppRouter.leaderboard => _fade(
          LeaderboardScreen(
            levelId: settings.arguments is LevelId
                ? settings.arguments as LevelId
                : LevelId('1'),
          ),
          settings,
        ),
      _ => _fade(const HomeScreen(), settings),
    };
  }

  // Reenvia `settings` a la ruta para que las pantallas destino puedan leer sus
  // `arguments` via ModalRoute (p.ej. VictoryScreen los movimientos, DefeatScreen
  // el LevelId a reintentar).
  static MaterialPageRoute<dynamic> _fade(Widget page, RouteSettings settings) =>
      MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
}

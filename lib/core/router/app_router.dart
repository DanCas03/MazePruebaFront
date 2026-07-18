import 'package:flutter/material.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../presentation/game/screens/game_screen.dart';
import '../../presentation/generated/configurator_screen.dart';
import '../../presentation/generated/generated_game_screen.dart';
import '../../presentation/generated/generated_result_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/leaderboard/screens/global_leaderboard_screen.dart';
import '../../presentation/leaderboard/screens/leaderboard_screen.dart';
import '../../presentation/level_selection/defeat_screen.dart';
import '../../presentation/level_selection/hex_selection_screen.dart';
import '../../presentation/level_selection/level_selection_screen.dart';
import '../../presentation/level_selection/themed_selection_screen.dart';
import '../../presentation/level_selection/victory_screen.dart';
import '../../presentation/settings/screens/settings_screen.dart';

/// Tabla de rutas nombradas de la app. Centraliza la navegacion (SRP) y
/// desacopla las pantallas entre si: cualquier widget navega por nombre de
/// ruta sin conocer la clase de pantalla destino.
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String levelSelection = '/levels';
  // front#100: sección temática, alcanzable desde el menú principal.
  static const String themed = '/themed';
  // front#127: modo hexagonal, alcanzable desde el menú principal (ADR-0007 D6).
  static const String hex = '/hex';
  static const String game = '/game';
  static const String victory = '/victory';
  static const String defeat = '/defeat';
  static const String leaderboard = '/leaderboard';
  // ADR 0006: ranking general de jugadores, accesible desde el menú principal.
  static const String globalLeaderboard = '/leaderboard/global';
  static const String settings = '/settings';

  // front#37: flujo de tableros generados por el jugador (configurador →
  // partida → post-partida). Rutas separadas de la campaña; comparten el
  // BoardView pero no el estado ni la persistencia.
  static const String generate = '/generate';
  static const String generatedGame = '/generate/play';
  static const String generatedResult = '/generate/result';

  // front#103: política de "camino de vuelta" centralizada. Antes cada pantalla
  // terminal (victoria, derrota, error de carga, post-partida generada) escribía
  // a mano su `pushNamedAndRemoveUntil` con el predicado de la pila; un descuido
  // (p. ej. `(_) => false`) borraba la raíz y dejaba al jugador varado. Estos dos
  // helpers son la ÚNICA fuente de la garantía "siempre se puede volver al menú":
  // conservan la ruta raíz `home` ('/', donde vive el AuthGate) bajo el destino,
  // de modo que la flecha de retorno del AppBar y el cierre de sesión reactivo
  // siguen funcionando desde cualquier pantalla alcanzable.

  /// Vuelve al selector de niveles conservando `home` ('/') debajo, para que la
  /// flecha de retorno auto-implícita del AppBar siga visible (regresión front#97).
  /// Usado por las pantallas de victoria, derrota y el error terminal de carga.
  static void backToLevels(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      levelSelection,
      ModalRoute.withName(home),
    );
  }

  /// Vuelve al menú principal descartando el sub-flujo actual (p. ej. el flujo
  /// de tableros generados) SIN borrar la raíz: hace `pop` hasta `home` ('/'),
  /// preservando el AuthGate montado en ella. Reemplaza al antiguo
  /// `pushNamedAndRemoveUntil(home, (_) => false)`, que quitaba el AuthGate y
  /// dejaba el cierre de sesión sin quien conmutara a Login (front#103).
  static void exitToHome(BuildContext context) {
    Navigator.popUntil(context, ModalRoute.withName(home));
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRouter.home => _fade(const HomeScreen(), settings),
      AppRouter.levelSelection => _fade(const LevelSelectionScreen(), settings),
      AppRouter.themed => _fade(const ThemedSelectionScreen(), settings),
      AppRouter.hex => _fade(const HexSelectionScreen(), settings),
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
      AppRouter.globalLeaderboard =>
        _fade(const GlobalLeaderboardScreen(), settings),
      AppRouter.leaderboard => _fade(
          LeaderboardScreen(
            levelId: settings.arguments is LevelId
                ? settings.arguments as LevelId
                : LevelId('1'),
          ),
          settings,
        ),
      AppRouter.settings => _fade(const SettingsScreen(), settings),
      AppRouter.generate => _fade(const ConfiguratorScreen(), settings),
      AppRouter.generatedGame => _fade(const GeneratedGameScreen(), settings),
      AppRouter.generatedResult =>
        _fade(const GeneratedResultScreen(), settings),
      _ => _fade(const HomeScreen(), settings),
    };
  }

  // Reenvia `settings` a la ruta para que las pantallas destino puedan leer sus
  // `arguments` via ModalRoute (p.ej. VictoryScreen los movimientos, DefeatScreen
  // el LevelId a reintentar).
  static MaterialPageRoute<dynamic> _fade(Widget page, RouteSettings settings) =>
      MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
}

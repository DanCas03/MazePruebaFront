// lib/application/providers/game_controller_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/game_controller.dart';
import '../state/game_state.dart';

/// Punto de entrada único que la UI observa para el estado del juego.
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

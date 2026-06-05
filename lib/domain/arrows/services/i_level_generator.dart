// lib/domain/arrows/services/i_level_generator.dart

import '../../game_core/value_objects/level_id.dart';
import '../entities/arrow_board.dart';

/// Puerto (DIP) que genera el tablero de un nivel.
///
/// La aplicación depende de esta abstracción; la implementación concreta
/// (procedural con grafos) vive en infraestructura y puede sustituirse (p. ej.
/// por niveles servidos desde el backend) sin tocar la lógica de juego.
abstract class ILevelGenerator {
  /// Devuelve un tablero RESOLUBLE para el nivel dado. El mismo [levelId]
  /// produce siempre el mismo tablero (generación determinista).
  ArrowBoard generate(LevelId levelId);
}

// lib/application/use_cases/arrows/remove_arrow_use_case.dart

import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/arrows/entities/arrow_board.dart';
import '../../../domain/game_core/value_objects/arrow_id.dart';
import '../../commands/command_invoker.dart';
import '../../commands/remove_arrow_command.dart';

/// Resultado posible al intentar sacar una flecha.
enum RemoveArrowOutcome { removed, blocked, notFound }

/// Resultado de [RemoveArrowUseCase.execute].
class RemoveArrowResult {
  final RemoveArrowOutcome outcome;

  /// `true` si tras sacar la flecha el tablero quedó completamente limpio.
  final bool boardCleared;

  /// Flecha afectada (la sacada o la bloqueada). `null` si no se encontró.
  /// La capa de presentación la usa para animarla.
  final Arrow? arrow;

  const RemoveArrowResult(this.outcome, {this.boardCleared = false, this.arrow});
}

/// Caso de uso: intentar sacar una flecha del tablero.
///
/// Aplica la regla de negocio (la flecha solo sale si su recorrido está libre)
/// y delega la mutación al [CommandInvoker] vía [RemoveArrowCommand], lo que
/// habilita el deshacer. No conoce Flutter.
class RemoveArrowUseCase {
  final ArrowBoard board;
  final CommandInvoker invoker;

  RemoveArrowUseCase({required this.board, required this.invoker});

  RemoveArrowResult execute(ArrowId id) {
    final arrow = board.findById(id);
    if (arrow == null) {
      return const RemoveArrowResult(RemoveArrowOutcome.notFound);
    }
    if (!board.canExit(arrow)) {
      return RemoveArrowResult(RemoveArrowOutcome.blocked, arrow: arrow);
    }

    invoker.executeCommand(RemoveArrowCommand(board: board, arrow: arrow));
    return RemoveArrowResult(
      RemoveArrowOutcome.removed,
      boardCleared: board.isCleared,
      arrow: arrow,
    );
  }
}

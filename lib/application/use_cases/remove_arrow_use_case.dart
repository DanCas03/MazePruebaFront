import 'package:dartz/dartz.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/core/exceptions/arrow_not_found_exception.dart';
import '../../domain/core/exceptions/domain_exception.dart';
import '../../domain/core/exceptions/invalid_move_exception.dart';

class RemoveArrowUseCase {
  Either<DomainException, ArrowBoard> execute(ArrowBoard board, ArrowId arrowId) {
    // Branch on membership first so the two distinct failure modes carry
    // accurate type+message: an absent id is a programming error
    // (ArrowNotFoundException); a present-but-blocked arrow is a legitimate
    // invalid move (InvalidMoveException). canExit() collapses both into false,
    // so the use case must disambiguate before returning a Left.
    if (!board.contains(arrowId)) {
      return Left(ArrowNotFoundException(
          'Arrow ${arrowId.value} not found on the board'));
    }
    if (!board.canExit(arrowId)) {
      return Left(InvalidMoveException(
          'Arrow ${arrowId.value} cannot exit — path is blocked'));
    }
    return Right(board.removeArrow(arrowId));
  }
}

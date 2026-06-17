import 'package:dartz/dartz.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/core/exceptions/arrow_not_found_exception.dart';
import '../../domain/core/exceptions/domain_exception.dart';

class RemoveArrowUseCase {
  Either<DomainException, ArrowBoard> execute(ArrowBoard board, ArrowId arrowId) {
    if (!board.canExit(arrowId)) {
      return Left(ArrowNotFoundException(
          'Arrow ${arrowId.value} cannot exit — path is blocked'));
    }
    return Right(board.removeArrow(arrowId));
  }
}

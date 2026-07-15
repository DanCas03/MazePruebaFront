import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/arrow_not_found_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/domain_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

Arrow _makeArrow({required String id, required int row, required int col,
    Direction dir = Direction.right, int len = 2}) =>
    straightArrow(id: ArrowId(id), tail: Position(row: row, col: col),
        direction: dir, length: len);

void main() {
  late RemoveArrowUseCase sut;

  setUp(() => sut = RemoveArrowUseCase());

  group('RemoveArrowUseCase', () {
    test('returns Right(newBoard) when arrow can exit', () {
      // Arrange
      final arrow = _makeArrow(id: 'a1', row: 0, col: 0);
      final board = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
      // Act
      final result = sut.execute(board, const ArrowId('a1'));
      // Assert
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (b) => expect(b.isCleared, isTrue));
    });

    test('returns Left(InvalidMoveException) when arrow exists but is blocked', () {
      // Arrange
      final arrow = _makeArrow(id: 'a1', row: 0, col: 0, len: 2);
      final blocker = _makeArrow(id: 'b1', row: 0, col: 2, dir: Direction.down, len: 1);
      final board = ArrowBoard(arrows: [arrow, blocker], space: RectSpace(4, 4));
      // Act
      final result = sut.execute(board, const ArrowId('a1'));
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold((e) {
        expect(e, isA<InvalidMoveException>());
        expect(e, isA<DomainException>());
        expect(e.message, contains('path is blocked'));
      }, (_) {});
    });

    test('returns Left(ArrowNotFoundException) when arrow id is absent', () {
      // Arrange
      final arrow = _makeArrow(id: 'a1', row: 0, col: 0, len: 2);
      final board = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
      // Act
      final result = sut.execute(board, const ArrowId('ghost'));
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold((e) {
        expect(e, isA<ArrowNotFoundException>());
        expect(e, isA<DomainException>());
        expect(e.message, contains('not found'));
      }, (_) {});
    });
  });
}

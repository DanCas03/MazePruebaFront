import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';

void main() {
  late GraphBoardGenerator sut;

  setUp(() => sut = GraphBoardGenerator());

  group('GraphBoardGenerator', () {
    test('generates a board with the requested number of arrows', () {
      // Arrange / Act
      final board = sut.generate(cols: 5, rows: 5, arrowCount: 4);
      // Assert
      expect(board.arrows.length, 4);
    });

    test('generated board is solvable — every arrow can eventually be removed',
        () {
      // Arrange
      final board = sut.generate(cols: 5, rows: 5, arrowCount: 5);
      final useCase = RemoveArrowUseCase();
      // Act — simulate solving: repeatedly remove any arrow that can exit
      ArrowBoard current = board;
      while (!current.isCleared) {
        final removable =
            current.arrows.where((a) => current.canExit(a.id)).toList();
        expect(removable, isNotEmpty,
            reason: 'Board must have at least one removable arrow at all times');
        final result = useCase.execute(current, removable.first.id);
        result.fold(
            (_) => fail('canExit returned true but use case returned Left'),
            (b) {
          current = b;
        });
      }
      expect(current.isCleared, isTrue);
    });

    test('two calls with same seed produce the same board', () {
      // GraphBoardGenerator accepts optional seed for determinism
      final boardA =
          GraphBoardGenerator(seed: 42).generate(cols: 4, rows: 4, arrowCount: 3);
      final boardB =
          GraphBoardGenerator(seed: 42).generate(cols: 4, rows: 4, arrowCount: 3);
      expect(boardA.arrows.length, boardB.arrows.length);
      for (var i = 0; i < boardA.arrows.length; i++) {
        expect(boardA.arrows[i], boardB.arrows[i]);
      }
    });
  });
}

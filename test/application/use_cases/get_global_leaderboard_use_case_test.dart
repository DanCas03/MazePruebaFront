import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/get_global_leaderboard_use_case.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';

import 'get_global_leaderboard_use_case_test.mocks.dart';

@GenerateMocks([ILeaderboardRepository])
void main() {
  late MockILeaderboardRepository repository;
  late GetGlobalLeaderboardUseCase useCase;

  setUp(() {
    repository = MockILeaderboardRepository();
    useCase = GetGlobalLeaderboardUseCase(repository);
  });

  test('should_delegate_to_port_and_return_its_result', () async {
    // Arrange
    final board = GlobalLeaderboard(
      top: [
        GlobalLeaderboardEntry(
          username: 'ana',
          totalScore: 900,
          totalStars: 12,
          rank: 1,
        ),
      ],
      me: null,
    );
    when(repository.getGlobalLeaderboard()).thenAnswer((_) async => board);
    // Act
    final result = await useCase.execute();
    // Assert
    expect(result, same(board));
    verify(repository.getGlobalLeaderboard()).called(1);
  });

  test('should_propagate_repository_errors', () async {
    // Arrange — la lectura NO es fire-and-forget: la UI necesita el error para
    // pintar el estado de reintento (mismo criterio que GetLeaderboardUseCase).
    when(repository.getGlobalLeaderboard()).thenThrow(Exception('red caída'));
    // Act / Assert
    expect(() => useCase.execute(), throwsException);
  });
}

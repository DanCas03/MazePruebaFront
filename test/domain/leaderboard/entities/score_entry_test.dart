import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';

ScoreEntry _entry({int timeSeconds = 45, int collisions = 2}) => ScoreEntry(
      levelId: LevelId('7'),
      score: Score(1200),
      stars: const Stars.three(),
      moves: const MoveCount(12),
      timeSeconds: timeSeconds,
      collisions: collisions,
    );

void main() {
  test('construye con los VOs del run', () {
    // Arrange / Act
    final entry = _entry();
    // Assert
    expect(entry.levelId.value, '7');
    expect(entry.score.value, 1200);
    expect(entry.stars.value, 3);
    expect(entry.moves.value, 12);
    expect(entry.timeSeconds, 45);
    expect(entry.collisions, 2);
  });

  test('igualdad por valor', () {
    // Arrange / Act / Assert
    expect(_entry(), _entry());
    // Un campo distinto (props truncado no lo detectaría) rompe la igualdad.
    expect(_entry(timeSeconds: 45), isNot(_entry(timeSeconds: 46)));
    expect(_entry(collisions: 2), isNot(_entry(collisions: 3)));
  });

  test('rechaza timeSeconds negativo', () {
    // Arrange / Act / Assert
    expect(() => _entry(timeSeconds: -1), throwsArgumentError);
  });

  test('rechaza collisions negativo', () {
    // Arrange / Act / Assert
    expect(() => _entry(collisions: -1), throwsArgumentError);
  });
}

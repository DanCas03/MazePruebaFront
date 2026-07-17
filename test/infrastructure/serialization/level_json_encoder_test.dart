import 'dart:convert';

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';

void main() {
  group('LevelJsonEncoder', () {
    late LevelJsonEncoder sut;

    setUp(() {
      // Arrange (shared) — the system under test is a pure, stateless encoder.
      sut = const LevelJsonEncoder();
    });

    test('should_serialize_wire_contract_keys_when_encoding_board', () {
      // Arrange — a minimal soluble board with a single straight arrow.
      final board = ArrowBoard(
        space: RectSpace(5, 6),
        arrows: [
          Arrow(
            id: ArrowId('a1'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
      );

      // Act — serialize to a map with no time limit.
      final map = sut.toMap(levelId: 'level-1', board: board);

      // Assert — exactly the base wire keys, no extras and no timeLimitSec.
      expect(
        map.keys.toSet(),
        equals(<String>{'levelId', 'cols', 'rows', 'arrows'}),
      );
      expect(map['levelId'], equals('level-1'));
      expect(map['cols'], equals(5));
      expect(map['rows'], equals(6));
      expect(map['arrows'], isA<List<Object?>>());
    });

    test('should_serialize_cells_tail_to_head_as_row_col_pairs_when_arrow_is_bent', () {
      // Arrange — a bent arrow: tail (10,3) -> (9,3) -> head (9,4).
      final board = ArrowBoard(
        space: RectSpace(8, 12),
        arrows: [
          Arrow(
            id: ArrowId('bent'),
            cells: [
              Position(row: 10, col: 3),
              Position(row: 9, col: 3),
              Position(row: 9, col: 4),
            ],
            headDirection: Direction.up,
          ),
        ],
      );

      // Act — serialize the board.
      final map = sut.toMap(levelId: 'bent-level', board: board);

      // Assert — cells preserve tail-to-head order as [row, col] pairs.
      final arrows = map['arrows'] as List<Object?>;
      final arrow = arrows.single as Map<String, Object?>;
      expect(arrow['id'], equals('bent'));
      expect(arrow['headDir'], equals('up'));
      expect(
        arrow['cells'],
        equals(<List<int>>[
          [10, 3],
          [9, 3],
          [9, 4],
        ]),
      );
    });

    test('should_map_head_direction_to_wire_string_when_encoding', () {
      // Arrange — one arrow per direction; expected wire strings by enum .name.
      final cases = <Direction, String>{
        Direction.up: 'up',
        Direction.down: 'down',
        Direction.left: 'left',
        Direction.right: 'right',
      };
      final board = ArrowBoard(
        space: RectSpace(4, 4),
        arrows: [
          for (final dir in cases.keys)
            Arrow(
              id: ArrowId(dir.name),
              cells: [Position(row: 1, col: 1), Position(row: 1, col: 2)],
              headDirection: dir,
            ),
        ],
      );

      // Act — serialize the multi-direction board.
      final map = sut.toMap(levelId: 'dirs', board: board);

      // Assert — each arrow's headDir matches the expected wire string.
      final arrows = (map['arrows'] as List<Object?>)
          .cast<Map<String, Object?>>();
      for (final arrow in arrows) {
        final expectedWire = cases.entries
            .firstWhere((e) => e.key.name == arrow['id'])
            .value;
        expect(arrow['headDir'], equals(expectedWire));
      }
    });

    test('should_omit_time_limit_sec_when_null', () {
      // Arrange — a board serialized without a time limit.
      final board = ArrowBoard(
        space: RectSpace(3, 3),
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
      );

      // Act — serialize with timeLimitSec left null.
      final map = sut.toMap(levelId: 'no-limit', board: board, timeLimitSec: null);

      // Assert — the key must be absent entirely, not present-with-null.
      expect(map.containsKey('timeLimitSec'), isFalse);
    });

    test('should_include_time_limit_sec_when_provided', () {
      // Arrange — a board with an explicit time limit.
      final board = ArrowBoard(
        space: RectSpace(3, 3),
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
      );

      // Act — serialize with a 90-second limit.
      final map = sut.toMap(levelId: 'limited', board: board, timeLimitSec: 90);

      // Assert — the key is present with the given value.
      expect(map.containsKey('timeLimitSec'), isTrue);
      expect(map['timeLimitSec'], equals(90));
    });

    test('should_serialize_empty_arrows_list_when_board_is_cleared', () {
      // Arrange — a cleared board with no arrows.
      final board = ArrowBoard(space: RectSpace(5, 5), arrows: const []);

      // Act — serialize the empty board.
      final map = sut.toMap(levelId: 'cleared', board: board);

      // Assert — arrows serializes to an empty list.
      expect(map['arrows'], isEmpty);
      expect(map['arrows'], isA<List<Object?>>());
    });

    // #118 — themed silhouette: role -> fill cells defining the shape of
    // themed levels. Ordering must be deterministic (row-major) for the
    // byte-stable golden to hold regardless of Set iteration order.
    test('should_emit_silhouette_with_row_major_ordered_cells_when_provided', () {
      // Arrange — a board plus a silhouette whose cells are given out of order.
      final board = ArrowBoard(
        space: RectSpace(6, 6),
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 3, col: 4), Position(row: 3, col: 5)],
            headDirection: Direction.right,
          ),
        ],
      );
      final silhouette = <String, Set<Position>>{
        'cara': {
          Position(row: 3, col: 5),
          Position(row: 2, col: 9),
          Position(row: 3, col: 4),
        },
      };

      // Act — serialize with the silhouette.
      final map = sut.toMap(levelId: 'themed', board: board, silhouette: silhouette);

      // Assert — the key is present, cells sorted row-major (row, then col).
      expect(map.containsKey('silhouette'), isTrue);
      expect(
        map['silhouette'],
        equals(<String, Object?>{
          'cara': [
            [2, 9],
            [3, 4],
            [3, 5],
          ],
        }),
      );
    });

    test('should_omit_silhouette_when_null', () {
      // Arrange — a plain campaign board serialized without a silhouette.
      final board = ArrowBoard(
        space: RectSpace(3, 3),
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
      );

      // Act — serialize with silhouette left null.
      final map = sut.toMap(levelId: 'no-silhouette', board: board);

      // Assert — the key must be absent entirely, not present-with-null.
      expect(map.containsKey('silhouette'), isFalse);
    });

    test('should_end_with_newline_and_two_space_indent_when_encode_returns_string', () {
      // Arrange — a board whose encoded form we inspect as a raw string.
      final board = ArrowBoard(
        space: RectSpace(2, 2),
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
      );

      // Act — encode to the JSON wire string.
      final json = sut.encode(levelId: 'pretty', board: board);

      // Assert — trailing newline, 2-space indentation, and round-trips to the map.
      expect(json.endsWith('\n'), isTrue);
      expect(json, contains('\n  "levelId"'));
      expect(
        jsonDecode(json),
        equals(sut.toMap(levelId: 'pretty', board: board)),
      );
    });
  });
}

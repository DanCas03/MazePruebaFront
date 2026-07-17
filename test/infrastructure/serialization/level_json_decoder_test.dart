import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/strike_count.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The canonical arrow-path wire map, verbatim from the CONTEXT-MAP root
/// example. Rebuilt fresh per test so no case can mutate another's fixture.
Map<String, Object?> canonicalWireMap() => <String, Object?>{
      'levelId': 'l-007',
      'cols': 8,
      'rows': 11,
      'timeLimitSec': 90,
      'arrows': [
        {
          'id': 'a1',
          'headDir': 'up',
          'cells': [
            [10, 3],
            [9, 3],
            [9, 4],
          ],
        },
        {
          'id': 'a2',
          'headDir': 'right',
          'cells': [
            [2, 0],
            [2, 1],
          ],
        },
      ],
    };

void main() {
  group('LevelJsonDecoder', () {
    late LevelJsonDecoder sut;

    setUp(() {
      // Arrange (shared) — the SUT is a pure, stateless strict decoder.
      sut = const LevelJsonDecoder();
    });

    test('should_reproduce_the_canonical_wire_map_when_re_encoding_the_decode', () {
      // Arrange — decode the canonical map, then re-encode with the inverse.
      const encoder = LevelJsonEncoder();
      final canonical = canonicalWireMap();

      // Act — golden round-trip: JSON -> Level -> JSON.
      final level = sut.decode(canonical);
      final reEncoded = encoder.toMap(
        levelId: level.id.value,
        board: level.board,
        timeLimitSec: level.timeLimitSec,
      );

      // Assert — the round-trip reproduces the original wire map byte-for-byte.
      expect(reEncoded, equals(canonical));
    });

    test('should_populate_every_domain_field_when_decoding_valid_json', () {
      // Arrange — the canonical map with a bent head arrow and a straight one.
      final canonical = canonicalWireMap();

      // Act — decode to the Level aggregate.
      final level = sut.decode(canonical);

      // Assert — identity, board dimensions, arrow count and the first arrow.
      expect(level.id, equals(LevelId('l-007')));
      expect(level.board.cols, equals(8));
      expect(level.board.rows, equals(11));
      expect(level.board.arrows.length, equals(2));
      expect(level.timeLimitSec, equals(90));

      final first = level.board.arrows.first;
      expect(first.headDirection, equals(Direction.up));
      expect(
        first.cells,
        equals(<Position>[
          Position(row: 10, col: 3),
          Position(row: 9, col: 3),
          Position(row: 9, col: 4),
        ]),
      );
    });

    test('should_decode_null_time_limit_when_key_is_absent', () {
      // Arrange — a valid map with no timeLimitSec key at all.
      final json = <String, Object?>{
        'levelId': 'l-008',
        'cols': 4,
        'rows': 4,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'right',
            'cells': [
              [0, 0],
              [0, 1],
            ],
          },
        ],
      };

      // Act — decode the map without a time limit.
      final level = sut.decode(json);

      // Assert — the optional limit surfaces as null, not a default.
      expect(level.timeLimitSec, isNull);
    });

    // front#83 — per-level error budget, additive/tolerant like timeLimitSec.
    test('should_default_maxErrors_to_the_strike_budget_when_key_is_absent', () {
      // Arrange — the canonical map carries no maxErrors.
      final level = sut.decode(canonicalWireMap());
      // Assert — absent ⇒ the default budget, never a crash.
      expect(level.maxErrors, StrikeCount.defaultMax);
    });

    test('should_decode_per_level_maxErrors_when_present', () {
      // Arrange
      final json = canonicalWireMap()..['maxErrors'] = 3;
      // Act
      final level = sut.decode(json);
      // Assert
      expect(level.maxErrors, 3);
    });

    test('should_throw_format_exception_when_maxErrors_is_not_an_int', () {
      // Arrange — a malformed budget of the wrong type.
      final bad = canonicalWireMap()..['maxErrors'] = '3';
      // Act & Assert
      expect(() => sut.decode(bad), throwsA(isA<FormatException>()));
    });

    test('should_round_trip_maxErrors_through_encode_when_present', () {
      // Arrange — decode a map WITH a budget, then re-encode passing it back.
      const encoder = LevelJsonEncoder();
      final canonical = canonicalWireMap()..['maxErrors'] = 3;
      // Act — JSON -> Level -> JSON preserving the budget.
      final level = sut.decode(canonical);
      final reEncoded = encoder.toMap(
        levelId: level.id.value,
        board: level.board,
        timeLimitSec: level.timeLimitSec,
        maxErrors: level.maxErrors,
      );
      // Assert — the budget survives the round-trip.
      expect(reEncoded['maxErrors'], 3);
    });

    test('should_throw_format_exception_when_cols_key_is_missing', () {
      // Arrange — a map missing the required cols key.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'rows': 11,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'up',
            'cells': [
              [10, 3],
            ],
          },
        ],
      };

      // Act & Assert — a missing wire key is a contract violation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_head_dir_is_unknown', () {
      // Arrange — an arrow whose headDir is not a Direction value.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'sideways',
            'cells': [
              [10, 3],
            ],
          },
        ],
      };

      // Act & Assert — an unmapped direction is a contract violation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_an_arrow_has_empty_cells', () {
      // Arrange — an arrow with no cells at all.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'up',
            'cells': <Object?>[],
          },
        ],
      };

      // Act & Assert — an arrow must own at least one cell.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_a_cell_is_not_a_row_col_pair', () {
      // Arrange — a cell with three coordinates instead of two.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'up',
            'cells': [
              [1, 2, 3],
            ],
          },
        ],
      };

      // Act & Assert — a malformed cell shape is a contract violation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_a_cell_coord_is_not_an_int', () {
      // Arrange — a cell whose row coordinate is a string.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'up',
            'cells': [
              ['x', 2],
            ],
          },
        ],
      };

      // Act & Assert — non-int coordinates are a contract violation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_not_domain_exception_when_arrows_is_empty', () {
      // Arrange — an empty board violates the Level domain invariant.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'arrows': <Object?>[],
      };

      // Act & Assert — the decoder must translate the domain invariant breach
      // into a FormatException (throwsFormatException fails on a leaked
      // InvalidLevelException, proving the DomainException -> FormatException
      // translation).
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_not_domain_exception_when_time_limit_is_zero', () {
      // Arrange — a non-positive time limit violates the Level invariant.
      final bad = <String, Object?>{
        'levelId': 'l-007',
        'cols': 8,
        'rows': 11,
        'timeLimitSec': 0,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'up',
            'cells': [
              [10, 3],
            ],
          },
        ],
      };

      // Act & Assert — the invalid limit surfaces as FormatException, again
      // proving the DomainException -> FormatException translation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    // front#67 — paint instructions (ADR 0004): a themed level carries an
    // opaque `palette` (role -> hex) and per-arrow `paintRole`, verbatim from
    // the CONTEXT-MAP § Themed extension example.
    Map<String, Object?> themedWireMap() => <String, Object?>{
          'levelId': 't-smiley',
          'cols': 20,
          'rows': 20,
          'arrows': [
            {
              'id': 'a1',
              'headDir': 'up',
              'cells': [
                [3, 4],
                [3, 5],
              ],
              'paintRole': 'cara',
            },
          ],
          'palette': {'cara': '#FBBF24', 'ojo': '#1E293B'},
        };

    test('should_round_trip_a_themed_level_with_palette_and_paint_roles', () {
      // Arrange
      const encoder = LevelJsonEncoder();
      final themed = themedWireMap();
      // Act — JSON -> Level -> JSON, threading palette back through the encoder.
      final level = sut.decode(themed);
      final reEncoded = encoder.toMap(
        levelId: level.id.value,
        board: level.board,
        timeLimitSec: level.timeLimitSec,
        palette: level.palette,
      );
      // Assert — themed fields survive the round-trip byte-for-byte.
      expect(reEncoded, equals(themed));
      expect(level.palette, equals({'cara': '#FBBF24', 'ojo': '#1E293B'}));
      expect(level.board.arrows.first.paintRole, equals('cara'));
    });

    test('should_decode_null_palette_and_paint_role_for_a_campaign_level', () {
      // Arrange — the canonical campaign map carries no themed fields.
      final canonical = canonicalWireMap();
      // Act
      final level = sut.decode(canonical);
      // Assert — absence means campaign, not a default.
      expect(level.palette, isNull);
      expect(level.board.arrows.every((a) => a.paintRole == null), isTrue);
    });

    test('should_throw_format_exception_when_palette_is_not_an_object', () {
      // Arrange — palette given as a list instead of a role->hex map.
      final bad = themedWireMap()..['palette'] = ['#FBBF24'];
      // Act & Assert — a shape deviation is a contract violation.
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_a_palette_value_is_not_a_string', () {
      // Arrange — a palette entry whose hex value is a number.
      final bad = themedWireMap()..['palette'] = {'cara': 0xFBBF24};
      // Act & Assert
      expect(() => sut.decode(bad), throwsFormatException);
    });

    test('should_throw_format_exception_when_paint_role_is_not_a_string', () {
      // Arrange — an arrow whose paintRole is a number.
      final bad = themedWireMap();
      ((bad['arrows'] as List).first as Map)['paintRole'] = 7;
      // Act & Assert
      expect(() => sut.decode(bad), throwsFormatException);
    });

    // front#99 — silhouette field (ADR 0006): a themed level may carry a
    // silhouette (role -> list of [row, col] pairs) to fill under the board.
    test('parses silhouette into Level', () {
      // Arrange
      final level = const LevelJsonDecoder().decode({
        'levelId': 't-x', 'cols': 4, 'rows': 4,
        'arrows': [
          {'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]], 'paintRole': 'heart'},
        ],
        'palette': {'heart': '#FF4D6D'},
        'silhouette': {'heart': [[0, 0], [0, 1], [1, 0]]},
      });
      expect(level.silhouette!['heart'], [
        Position(row: 0, col: 0), Position(row: 0, col: 1), Position(row: 1, col: 0),
      ]);
    });

    test('rejects malformed silhouette', () {
      expect(() => const LevelJsonDecoder().decode({
        'levelId': 't-x', 'cols': 4, 'rows': 4,
        'arrows': [{'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]]}],
        'silhouette': {'heart': [[0]]}, // not a [row,col] pair
      }), throwsA(isA<FormatException>()));
    });

    test('golden: encode(decode(themed)) reproduces the map', () {
      // Arrange
      const encoder = LevelJsonEncoder();
      final json = {
        'levelId': 't-x', 'cols': 4, 'rows': 4,
        'arrows': [
          {'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]], 'paintRole': 'heart'},
        ],
        'palette': {'heart': '#FF4D6D'},
        'silhouette': {'heart': [[0, 0], [0, 1], [1, 0]]},
      };
      // Act
      final level = const LevelJsonDecoder().decode(json);
      final map = encoder.toMap(
        levelId: level.id.value, board: level.board,
        palette: level.palette, silhouette: level.silhouette);
      // Assert
      expect(map['silhouette'], json['silhouette']);
    });
  });
}

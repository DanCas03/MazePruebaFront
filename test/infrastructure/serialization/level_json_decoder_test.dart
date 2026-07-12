import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
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
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

import '../../../tool/level_production/candidate_producer.dart';
import '../../../tool/level_production/ramp.dart';
import '../../../tool/level_production/validation.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';

void main() {
  group('CandidateSpec — identidad trazable', () {
    test('el id es cand-t<tier>-s<seed> con la semilla rellenada a 3 dígitos', () {
      expect(CandidateSpec(step: rampStepFor(1), seed: 42).levelId, 'cand-t1-s042');
      expect(CandidateSpec(step: rampStepFor(3), seed: 300).levelId, 'cand-t3-s300');
      expect(CandidateSpec(step: rampStepFor(5, finale: true), seed: 900).levelId,
          'cand-t5-s900');
    });
  });

  group('produceCandidate — salida y determinismo', () {
    test('produce un candidato T1 válido con las claves del formato', () {
      final result = produceCandidate(CandidateSpec(step: rampStepFor(1), seed: 101));
      final map = jsonDecode(result.json) as Map<String, dynamic>;

      expect(map['levelId'], 'cand-t1-s101');
      expect(map['order'], 1); // placeholder de curación = tier
      expect(map['cols'], 6);
      expect(map['rows'], 10);
      expect(map['timeLimitSec'], rampStepFor(1).timeLimitSec); // 30 (back#46: T1 ahora cronometrado)
      expect(map['arrows'], isA<List<dynamic>>());
      expect((map['arrows'] as List).isNotEmpty, isTrue);

      expect(result.tier, 1);
      expect(result.placedArrows, greaterThan(0));
      expect(result.achievedDensity, greaterThan(0));
    });

    test('un tier con límite emite timeLimitSec derivado de la Rampa', () {
      final result = produceCandidate(CandidateSpec(step: rampStepFor(3), seed: 300));
      final map = jsonDecode(result.json) as Map<String, dynamic>;
      expect(map['timeLimitSec'], rampStepFor(3).timeLimitSec); // 120
      expect(map['order'], 3);
    });

    test('es determinista: misma semilla + parámetros ⇒ JSON idéntico', () {
      final a = produceCandidate(CandidateSpec(step: rampStepFor(2), seed: 202));
      final b = produceCandidate(CandidateSpec(step: rampStepFor(2), seed: 202));
      expect(a.json, b.json);
    });

    test('el candidato producido pasa las invariantes de validación', () {
      // produceCandidate ya valida internamente (lanzaría si no); aquí se afirma
      // explícito sobre el mismo tablero regenerado con la misma seed.
      final step = rampStepFor(2);
      final board = GraphBoardGenerator().generate(
        cols: step.cols,
        rows: step.rows,
        arrowCount: step.arrowCount,
        maxPathLen: step.maxPathLen,
        seed: 202,
      );
      expect(hasNoOverlap(board), isTrue);
      expect(emptiesInReverseOrder(board), isTrue);
      expect(() => validateCandidate(board), returnsNormally);
    });
  });

  group('validación — detecta candidatos rotos', () {
    test('hasNoOverlap es false y validateCandidate lanza si dos flechas comparten celda', () {
      final shared = Position(row: 0, col: 0);
      final board = ArrowBoard(
        space: RectSpace(4, 4),
        arrows: [
          Arrow(
            id: const ArrowId('arrow-0'),
            cells: [Position(row: 0, col: 1), shared],
            headDirection: Direction.left,
          ),
          Arrow(
            id: const ArrowId('arrow-1'),
            cells: [Position(row: 1, col: 0), shared],
            headDirection: Direction.up,
          ),
        ],
      );

      expect(hasNoOverlap(board), isFalse);
      expect(() => validateCandidate(board), throwsA(isA<CandidateValidationException>()));
    });

    test('validateCandidate lanza en un tablero vacío', () {
      final empty = const ArrowBoard(space: RectSpace(4, 4), arrows: []);
      expect(() => validateCandidate(empty), throwsA(isA<CandidateValidationException>()));
    });
  });
}

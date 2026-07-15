import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/configurator_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';

void main() {
  group('ConfiguratorState · validez', () {
    test('semilla vacía es válida (aleatoria) y produce seed null', () {
      const s = ConfiguratorState(seedText: '');
      expect(s.isSeedValid, isTrue);
      expect(s.isValid, isTrue);
      expect(s.seed, isNull);
    });

    test('semilla numérica es válida y se parsea a entero', () {
      const s = ConfiguratorState(seedText: '12345');
      expect(s.isSeedValid, isTrue);
      expect(s.isValid, isTrue);
      expect(s.seed, 12345);
    });

    test('semilla no numérica invalida el formulario', () {
      const s = ConfiguratorState(seedText: 'abc');
      expect(s.isSeedValid, isFalse);
      expect(s.isValid, isFalse);
    });

    test('dimensiones fuera de rango invalidan aunque la semilla sea válida', () {
      const tooSmall = ConfiguratorState(cols: 3, seedText: '1');
      const tooBig = ConfiguratorState(rows: 51, seedText: '1');
      expect(tooSmall.isValid, isFalse);
      expect(tooBig.isValid, isFalse);
    });
  });

  group('ConfiguratorState · toConfig', () {
    test('traslada la intención del jugador a GeneratorConfig', () {
      const s = ConfiguratorState(
        cols: 7,
        rows: 9,
        difficulty: Difficulty.hard,
        timed: true,
        seedText: '42',
      );

      final config = s.toConfig();

      expect(config.cols, 7);
      expect(config.rows, 9);
      expect(config.difficulty, Difficulty.hard);
      expect(config.timed, isTrue);
      expect(config.seed, 42);
    });

    test('sin semilla, GeneratorConfig la deja null (la fija el caso de uso)', () {
      const s = ConfiguratorState(seedText: '');
      expect(s.toConfig().seed, isNull);
    });
  });
}

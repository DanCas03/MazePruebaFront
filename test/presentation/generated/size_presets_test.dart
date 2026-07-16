import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/aspect_band.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/presentation/generated/size_presets.dart';

void main() {
  group('kSizePresets', () {
    test('every preset is inside the aspect band', () {
      for (final p in kSizePresets) {
        expect(AspectBand.contains(p.cols, p.rows), isTrue,
            reason: '${p.label} ${p.cols}x${p.rows} out of band');
      }
    });
    test('every preset is a portrait shape within dimension bounds', () {
      for (final p in kSizePresets) {
        expect(p.cols, lessThan(p.rows));
        expect(p.cols, greaterThanOrEqualTo(GeneratorConfig.minDimension));
        expect(p.rows, lessThanOrEqualTo(GeneratorConfig.maxDimension));
      }
    });
    test('every preset builds a valid GeneratorConfig', () {
      for (final p in kSizePresets) {
        expect(
            () => GeneratorConfig.create(
                cols: p.cols, rows: p.rows, difficulty: Difficulty.medium),
            returnsNormally);
      }
    });
  });
}

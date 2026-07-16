import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/band_layout.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  // Distancia al borde para una celda en un tablero cols×rows.
  int distanceToEdge(int r, int c, int rows, int cols) =>
      [r, c, rows - 1 - r, cols - 1 - c].reduce((a, b) => a < b ? a : b);

  group('concentricBands', () {
    test(
        'should_partition_all_cells_into_3_bands_without_overlap_when_20x20',
        () {
      // Arrange
      const cols = 20;
      const rows = 20;

      // Act
      final bands = concentricBands(cols: cols, rows: rows);

      // Assert
      expect(bands.length, 3, reason: '20x20 => 3 bandas');

      // Union == 400 celdas, sin solapamiento (cada celda en exactamente una).
      final all = <Position>[];
      for (final band in bands) {
        all.addAll(band);
      }
      expect(all.length, 400, reason: 'suma de tamaños cubre todas las celdas');
      expect(all.toSet().length, 400, reason: 'sin celdas duplicadas');

      // Cobertura exacta del conjunto de todas las celdas.
      final expected = <Position>{
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++) Position(row: r, col: c),
      };
      expect(all.toSet(), expected);

      // Banda 0 (interior) contiene solo celdas con d>=6.
      for (final p in bands[0]) {
        expect(distanceToEdge(p.row, p.col, rows, cols),
            greaterThanOrEqualTo(6));
      }

      // Banda 2 (exterior) incluye todo el perímetro (todas las celdas d==0).
      final perimeter = <Position>{
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            if (distanceToEdge(r, c, rows, cols) == 0) Position(row: r, col: c),
      };
      expect(bands[2].toSet().containsAll(perimeter), isTrue,
          reason: 'la banda exterior contiene todo el perímetro');
    });

    test('should_return_single_band_with_all_cells_when_2x2', () {
      // Arrange
      const cols = 2;
      const rows = 2;

      // Act
      final bands = concentricBands(cols: cols, rows: rows);

      // Assert
      expect(bands.length, 1, reason: '2x2 => maxD=0 => 1 banda');
      expect(bands[0].length, 4);
      final expected = <Position>{
        Position(row: 0, col: 0),
        Position(row: 0, col: 1),
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
      };
      expect(bands[0].toSet(), expected);
    });

    test('should_map_each_distance_to_its_own_band_when_6x8', () {
      // Arrange
      const cols = 8;
      const rows = 6; // maxD = (min(6,8)-1)~/2 = 2

      // Act
      final bands = concentricBands(cols: cols, rows: rows);

      // Assert
      expect(bands.length, 3, reason: '6x8 => maxD=2 => 3 bandas');

      // Con maxD=2 y k=3 cada banda corresponde a un único valor de distancia:
      // banda 0 -> d==2, banda 1 -> d==1, banda 2 -> d==0.
      for (final p in bands[0]) {
        expect(distanceToEdge(p.row, p.col, rows, cols), 2);
      }
      for (final p in bands[1]) {
        expect(distanceToEdge(p.row, p.col, rows, cols), 1);
      }
      for (final p in bands[2]) {
        expect(distanceToEdge(p.row, p.col, rows, cols), 0);
      }

      // Partición completa sin solapamiento.
      final all = <Position>[];
      for (final band in bands) {
        all.addAll(band);
      }
      expect(all.length, rows * cols);
      expect(all.toSet().length, rows * cols);
    });
  });

  group('largestRemainderQuotas', () {
    test('should_sum_exactly_to_total_when_remainders_present', () {
      // Arrange
      const total = 10;
      final sizes = [1, 1, 1];

      // Act
      final quotas = largestRemainderQuotas(total, sizes);

      // Assert
      expect(quotas.fold<int>(0, (a, b) => a + b), total);
      expect(quotas.length, sizes.length);
    });

    test('should_distribute_proportionally_when_sizes_are_10_20_30', () {
      // Arrange
      const total = 30;
      final sizes = [10, 20, 30];

      // Act
      final quotas = largestRemainderQuotas(total, sizes);

      // Assert
      expect(quotas, [5, 10, 15]);
      expect(quotas.fold<int>(0, (a, b) => a + b), total);
    });

    test('should_return_all_zeros_when_sizes_are_all_zero', () {
      // Arrange
      const total = 10;
      final sizes = [0, 0, 0];

      // Act
      final quotas = largestRemainderQuotas(total, sizes);

      // Assert
      expect(quotas, [0, 0, 0]);
    });

    test('should_return_all_zeros_when_total_is_zero', () {
      // Arrange
      const total = 0;
      final sizes = [10, 20, 30];

      // Act
      final quotas = largestRemainderQuotas(total, sizes);

      // Assert
      expect(quotas, [0, 0, 0]);
      expect(quotas.fold<int>(0, (a, b) => a + b), 0);
    });
  });
}

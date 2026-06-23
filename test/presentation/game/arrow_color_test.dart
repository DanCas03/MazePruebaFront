import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/presentation/game/arrow_color.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';

void main() {
  // --- Task 1.1: AppColors.arrowPalette + arrowColor (wrap-around helper) ---
  group('AppColors.arrowColor', () {
    test('mapea índices dentro de rango a su color de paleta', () {
      // Arrange / Act / Assert
      expect(AppColors.arrowColor(0), AppColors.arrowPalette[0]);
      expect(AppColors.arrowColor(7), AppColors.arrowPalette[7]);
    });

    test('hace wrap-around módulo el tamaño de la paleta', () {
      expect(AppColors.arrowColor(8), AppColors.arrowPalette[0]);
      expect(AppColors.arrowColor(9), AppColors.arrowPalette[1]);
    });

    test('la paleta tiene 8 colores', () {
      expect(AppColors.arrowPalette.length, 8);
    });
  });

  // --- Task 1.3: arrowColorIndex + arrowColorFor (helper de presentación) ---
  group('arrowColorIndex', () {
    test('parsea el sufijo numérico de "arrow-N" en rango', () {
      expect(arrowColorIndex(const ArrowId('arrow-0')), 0);
      expect(arrowColorIndex(const ArrowId('arrow-3')), 3);
    });

    test('hace wrap-around con la paleta', () {
      expect(arrowColorIndex(const ArrowId('arrow-8')), 0);
      expect(arrowColorIndex(const ArrowId('arrow-10')), 2);
    });

    test('es estable: el mismo id devuelve siempre el mismo índice', () {
      final a = arrowColorIndex(const ArrowId('arrow-5'));
      final b = arrowColorIndex(const ArrowId('arrow-5'));
      expect(a, b);
    });

    test('fallback determinista para ids no numéricos', () {
      final i = arrowColorIndex(const ArrowId('weird-id'));
      expect(i, inInclusiveRange(0, 7));
    });
  });
}

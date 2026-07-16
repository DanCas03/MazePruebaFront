import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/aspect_band.dart';

void main() {
  group('AspectBand', () {
    test('target ratio is 9:16', () {
      expect(AspectBand.targetRatio, closeTo(0.5625, 1e-9));
    });

    test('contains accepts shapes inside the band (inclusive edges)', () {
      expect(AspectBand.contains(9, 16), isTrue);   // 0.5625 target
      expect(AspectBand.contains(6, 10), isTrue);   // 0.600
      expect(AspectBand.contains(12, 22), isTrue);  // 0.545
      expect(AspectBand.contains(53, 100), isTrue); // 0.53 low edge
      expect(AspectBand.contains(68, 100), isTrue); // 0.68 high edge
    });

    test('contains rejects shapes outside the band', () {
      expect(AspectBand.contains(6, 8), isFalse);   // 0.75  > 0.68
      expect(AspectBand.contains(25, 25), isFalse); // 1.0   square
      expect(AspectBand.contains(10, 20), isFalse); // 0.50  < 0.53
    });

    test('snapRowsForCols puts a fixed cols nearest the target and stays in band', () {
      expect(AspectBand.snapRowsForCols(6), 11);    // 6 / 0.5625 = 10.67 -> 11
      expect(AspectBand.contains(6, AspectBand.snapRowsForCols(6)), isTrue);
      expect(AspectBand.contains(9, AspectBand.snapRowsForCols(9)), isTrue);
    });
  });
}

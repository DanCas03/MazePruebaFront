import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

const _sqrt3 = 1.7320508075688772;

void main() {
  // Constraints grandes y cuadrados: fit height-bound para R=2 (3R+2=8 vs
  // √3·(2R+1)≈8.66) => s = 800/(√3·5) ≈ 92.4 (width-bound daría s=100, que
  // haría height ≈ 866 > 800, luego el mínimo lo fija la altura).
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('size = (s(3R+2), √3·s(2R+1)) y cellSize = √3·s', () {
    final g = HexGeometry(const HexSpace(2), c);
    // s = min(800/8, 800/8.6602..) = 800/8.6602.. = 92.376..
    final s = 800 / (_sqrt3 * 5);
    expect(g.size.width, closeTo(s * 8, 1e-6));
    expect(g.size.height, closeTo(_sqrt3 * s * 5, 1e-6));
    expect(g.cellSize, closeTo(_sqrt3 * s, 1e-6));
  });

  test('centerOf del centro del hex (q=0,r=0) está en el centro del contenido', () {
    final g = HexGeometry(const HexSpace(2), c);
    final s = 800 / (_sqrt3 * 5);
    // q=0,r=0 => x = originX = 1.5sR+s ; y = originY = √3sR+√3s/2
    final center = g.centerOf(Position(row: 2, col: 2)); // col=q+R=2, row=r+R=2
    expect(center.dx, closeTo(1.5 * s * 2 + s, 1e-6));
    expect(center.dy, closeTo(_sqrt3 * s * 2 + _sqrt3 * s / 2, 1e-6));
  });

  test('los 6 vectores unidad · cellSize = centerOf(vecino) − centerOf(celda)', () {
    // Invariante verificada: directionUnit (front#124) coincide con la
    // proyección flat-top. Se comprueba desde el centro del hex R=3.
    final g = HexGeometry(const HexSpace(3), c);
    final cellPos = Position(row: 3, col: 3); // q=0,r=0
    final cs = g.cellSize;
    final expected = {
      Direction.up: const Offset(0, -1),
      Direction.down: const Offset(0, 1),
      Direction.upRight: Offset(math.sqrt(3) / 2, -0.5),
      Direction.downRight: Offset(math.sqrt(3) / 2, 0.5),
      Direction.upLeft: Offset(-math.sqrt(3) / 2, -0.5),
      Direction.downLeft: Offset(-math.sqrt(3) / 2, 0.5),
    };
    for (final entry in expected.entries) {
      final neighbor = const HexSpace(3).step(cellPos, entry.key)!;
      final delta = g.centerOf(neighbor) - g.centerOf(cellPos);
      expect(delta.dx, closeTo(entry.value.dx * cs, 1e-6), reason: '${entry.key}.dx');
      expect(delta.dy, closeTo(entry.value.dy * cs, 1e-6), reason: '${entry.key}.dy');
    }
  });
}

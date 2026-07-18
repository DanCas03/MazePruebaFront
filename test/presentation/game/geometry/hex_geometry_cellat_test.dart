import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('el centro exacto de cada celda mapea a su celda (R=3)', () {
    final g = HexGeometry(const HexSpace(3), c);
    for (final p in const HexSpace(3).allCells) {
      expect(g.cellAt(g.centerOf(p)), p, reason: '$p');
    }
  });

  test('un punto cerca del borde de una celda sigue mapeando a esa celda', () {
    final g = HexGeometry(const HexSpace(3), c);
    final p = Position(row: 3, col: 3); // centro
    final near = g.centerOf(p) + Offset(g.cellSize * 0.2, 0);
    expect(g.cellAt(near), p);
  });

  test('la esquina de la caja (fuera del hexágono) devuelve null', () {
    final g = HexGeometry(const HexSpace(3), c);
    // (row=0,col=0) => q=r=-3 => |q+r|=6>3: fuera del hex.
    expect(g.cellAt(const Offset(0, 0)), isNull);
  });

  test(
    'una celda no negativa dentro de la caja pero fuera del hexágono devuelve null',
    () {
      // (row=6,col=6) => q=col-R=3, r=row-R=3 => |q+r|=6>3: fuera del hex,
      // pero row y col son no negativos y caen dentro de la caja (2R+1)=7.
      // Este caso cubre el shape gate de HexSpace.contains, a diferencia de
      // la esquina (0,0) que ya devuelve null por el guard de índice negativo.
      final outOfHex = Position(row: 6, col: 6);
      expect(const HexSpace(3).contains(outOfHex), isFalse);

      final g = HexGeometry(const HexSpace(3), c);
      expect(g.cellAt(g.centerOf(outOfHex)), isNull);
    },
  );

  test('una celda enmascarada (hueco) devuelve null', () {
    final active = const HexSpace(1).allCells.toSet()
      ..remove(Position(row: 1, col: 1));
    final space = HexMaskedSpace(1, activeCells: active);
    final g = HexGeometry(space, c); // HexMaskedSpace ES HexSpace
    expect(g.cellAt(g.centerOf(Position(row: 1, col: 1))), isNull);
    // una celda activa del anillo sí mapea
    final ring = Position(row: 0, col: 1);
    expect(g.cellAt(g.centerOf(ring)), ring);
  });
}

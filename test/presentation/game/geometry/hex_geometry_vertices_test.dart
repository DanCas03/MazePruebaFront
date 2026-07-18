import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

const _sqrt3 = 1.7320508075688772;

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('cellVertices son 6 vértices flat-top alrededor del centro', () {
    final g = HexGeometry(const HexSpace(2), c);
    final p = Position(row: 2, col: 2); // centro
    final center = g.centerOf(p);
    final s = g.cellSize / _sqrt3; // circunradio
    final h = _sqrt3 / 2 * s;
    final v = g.cellVertices(p);
    expect(v.length, 6);
    expect(v[0].dx, closeTo(center.dx + s, 1e-6)); // derecha
    expect(v[0].dy, closeTo(center.dy, 1e-6));
    expect(v[1].dx, closeTo(center.dx + s / 2, 1e-6)); // abajo-derecha
    expect(v[1].dy, closeTo(center.dy + h, 1e-6));
    expect(v[3].dx, closeTo(center.dx - s, 1e-6)); // izquierda
  });

  test('exitLane delega en space.exitLane (downRight, R=2)', () {
    final g = HexGeometry(const HexSpace(2), c);
    final head = Position(row: 2, col: 2); // q=0,r=0
    expect(g.exitLane(head, Direction.downRight),
        const HexSpace(2).exitLane(head, Direction.downRight));
    expect(g.exitLane(head, Direction.downRight), isNotEmpty);
  });
}

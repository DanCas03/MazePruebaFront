import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'board_geometry.dart';

const double _sqrt3 = 1.7320508075688772;

/// Geometría hexagonal flat-top (ADR-0007 D1): proyecta las coordenadas axiales
/// del [HexSpace] a píxeles y de vuelta. Objeto plano (sin BuildContext),
/// unit-testable en AAA con un Size fijo.
class HexGeometry implements BoardGeometry {
  final HexSpace space;
  final int _r;
  final double _s; // circunradio de celda

  HexGeometry(this.space, BoxConstraints c)
      : _r = space.radius,
        _s = math.min(
          c.maxWidth / (3 * space.radius + 2),
          c.maxHeight / (_sqrt3 * (2 * space.radius + 1)),
        );

  // Origen de encuadre: desplaza el contenido para que quepa en [0, size].
  // Getters (no campos) porque dependen de _s, que el inicializador ya fijó.
  double get _ox => 1.5 * _s * _r + _s;
  double get _oy => _sqrt3 * _s * _r + _sqrt3 * _s / 2;

  @override
  Size get size => Size(_s * (3 * _r + 2), _sqrt3 * _s * (2 * _r + 1));

  @override
  double get cellSize => _sqrt3 * _s;

  @override
  Offset centerOf(Position p) {
    final q = p.col - _r;
    final r = p.row - _r;
    return Offset(
      1.5 * _s * q + _ox,
      _sqrt3 * _s * (r + q / 2) + _oy,
    );
  }

  @override
  Position? cellAt(Offset px) {
    // Píxel -> axial fraccional (inverso de centerOf).
    final x = px.dx - _ox;
    final y = px.dy - _oy;
    final qf = x / (1.5 * _s);
    final rf = y / (_sqrt3 * _s) - qf / 2;
    // Redondeo cúbico estándar (x=q, z=r, y=-x-z).
    var rx = qf.roundToDouble();
    var rz = rf.roundToDouble();
    var ry = (-qf - rf).roundToDouble();
    final dx = (rx - qf).abs();
    final dz = (rz - rf).abs();
    final dy = (ry - (-qf - rf)).abs();
    if (dx > dy && dx > dz) {
      rx = -ry - rz;
    } else if (dy > dz) {
      // y tiene el mayor error: q y r se conservan
    } else {
      rz = -rx - ry;
    }
    final row = rz.toInt() + _r;
    final col = rx.toInt() + _r;
    if (row < 0 || col < 0) return null;
    final pos = Position(row: row, col: col);
    return space.contains(pos) ? pos : null;
  }

  @override
  List<Position> exitLane(Position head, Direction dir) =>
      throw UnimplementedError('Task 4');
}

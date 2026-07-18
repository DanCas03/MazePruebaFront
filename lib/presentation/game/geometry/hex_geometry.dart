import 'package:flutter/widgets.dart';

import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'board_geometry.dart';

/// Stub de andamiaje (front#126 Task 1): el factory `BoardGeometry.forSpace`
/// necesita esta clase para compilar cuando el espacio es [HexSpace]. La
/// implementación real llega en front#126 Task 2+; hasta entonces, todo
/// miembro falla explícitamente en vez de devolver geometría incorrecta.
class HexGeometry implements BoardGeometry {
  HexGeometry(HexSpace space, BoxConstraints c);

  @override
  Size get size => throw UnimplementedError('front#126 Task 2+');

  @override
  double get cellSize => throw UnimplementedError('front#126 Task 2+');

  @override
  Offset centerOf(Position p) => throw UnimplementedError('front#126 Task 2+');

  @override
  Position? cellAt(Offset px) => throw UnimplementedError('front#126 Task 2+');

  @override
  List<Position> exitLane(Position head, Direction dir) =>
      throw UnimplementedError('front#126 Task 2+');
}

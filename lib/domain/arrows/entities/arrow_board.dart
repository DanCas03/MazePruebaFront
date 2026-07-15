import 'package:equatable/equatable.dart';
import 'arrow.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/space/board_space.dart';
import '../../game_core/space/rect_space.dart';
import '../../game_core/value_objects/position.dart';

// Aggregate Root: único punto de acceso al estado del tablero de flechas.
class ArrowBoard extends Equatable {
  final List<Arrow> arrows;
  final BoardSpace space;

  const ArrowBoard({
    required this.arrows,
    required this.space,
  });

  // cols/rows delegados (ADR-0005 D4): todo espacio concreto de HOY (RectSpace
  // y su único subtipo HoledRectSpace) tiene bounding box rectangular, así que
  // exponer cols/rows aquí evita tocar cada widget/encoder que ya los lee. No
  // es parte del contrato de BoardSpace — un espacio no-rectangular futuro
  // rompería este cast a propósito (documentado, no implementado: ADR-0005 §8).
  int get cols => (space as RectSpace).cols;
  int get rows => (space as RectSpace).rows;

  // Caché de ocupación por instancia (#64): ArrowBoard es inmutable, así que
  // el Set de celdas ocupadas se computa lazy UNA vez por instancia en lugar
  // de reconstruirse en cada canExit/overlaps. Se usa un Expando estático (y
  // no un campo `late final`) para conservar el constructor const — parte de
  // la interface pública (hay consumidores que construyen en contexto const).
  // removeArrow devuelve una instancia nueva, cuyo caché se recomputa lazy
  // una vez (O(N) por toque, aceptable). El Expando no impide el GC de los
  // tableros descartados.
  static final Expando<Set<Position>> _occupiedCache =
      Expando<Set<Position>>('ArrowBoard occupancy');

  Set<Position> get _occupied =>
      _occupiedCache[this] ??= {for (final a in arrows) ...a.cells};

  bool get isCleared => arrows.isEmpty;

  bool contains(ArrowId id) => _findById(id) != null;

  Arrow? arrowById(ArrowId id) => _findById(id);

  Arrow? arrowAt(Position pos) {
    for (final a in arrows) {
      if (a.cells.contains(pos)) return a;
    }
    return null;
  }

  Arrow? _findById(ArrowId id) {
    for (final a in arrows) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool overlaps(Arrow arrow) {
    final ownCells = _findById(arrow.id)?.cells.toSet() ?? const <Position>{};
    return arrow.cells.any((c) => _occupied.contains(c) && !ownCells.contains(c));
  }

  bool canExit(ArrowId id) {
    final arrow = _findById(id);
    if (arrow == null) return false;
    // Mecánica serpiente: el cuerpo se retrae por su propio camino, así que
    // las celdas de la PROPIA flecha nunca bloquean su salida (una serpiente
    // doblada puede tener cuerpo geométricamente delante de la cabeza).
    final ownCells = arrow.cells.toSet();
    return space
        .exitLane(arrow.head, arrow.headDirection)
        .every((p) => !_occupied.contains(p) || ownCells.contains(p));
  }

  ArrowBoard removeArrow(ArrowId id) {
    return ArrowBoard(
      arrows: arrows.where((a) => a.id != id).toList(),
      space: space,
    );
  }

  @override
  List<Object?> get props => [arrows, space];
}

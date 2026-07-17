import 'package:equatable/equatable.dart';
import 'arrow.dart';
import '../value_objects/arrow_id.dart';
import '../../core/exceptions/invalid_arrow_exception.dart';
import '../../game_core/space/board_space.dart';
import '../../game_core/value_objects/position.dart';

// Aggregate Root: único punto de acceso al estado del tablero de flechas.
class ArrowBoard extends Equatable {
  final List<Arrow> arrows;
  final BoardSpace space;

  const ArrowBoard({
    required this.arrows,
    required this.space,
  });

  // cols/rows delegados a la caja envolvente del espacio (#85, Fase 1): antes
  // se hacía un downcast duro al subtipo RectSpace, que rompía cualquier
  // geometría no rectangular. Ahora salen de `space.bounds`, que TODO
  // BoardSpace expone (default derivado de allCells; RectSpace en O(1)) — sin
  // conocer el subtipo concreto.
  int get cols => space.bounds.cols;
  int get rows => space.bounds.rows;

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

  // Seam de montaje (#118, Task 3): re-monta el MISMO contenido de flechas
  // sobre un BoardSpace DISTINTO (p. ej. campaña rectangular → MaskedSpace de
  // silueta temática). El constructor de ArrowBoard es `const` con cuerpo
  // vacío a propósito — mantenerlo así es interfaz pública documentada (la
  // caché de ocupación por Expando de arriba existe para preservar el
  // constructor const, y hay consumidores como
  // test/tool/level_production/candidate_producer_test.dart:98 que construyen
  // en contexto const) y un pase O(celdas) en CADA construcción penalizaría
  // también a `removeArrow`, que corre en cada movimiento de la partida. Por
  // eso la validación vive aquí, no en el constructor: si el nuevo espacio no
  // contiene alguna celda de alguna flecha, es un montaje inválido. En
  // producción esta guarda nunca debería dispararse (`Level` ya exige que las
  // flechas ⊆ silhouetteUnion, y la máscara se construye desde esa misma
  // unión) — es defensa en profundidad del seam, no código muerto.
  ArrowBoard remountedOn(BoardSpace newSpace) {
    for (final arrow in arrows) {
      for (final cell in arrow.cells) {
        if (!newSpace.contains(cell)) {
          throw InvalidArrowException(
            'remountedOn: la flecha ${arrow.id} tiene una celda $cell fuera '
            'del nuevo espacio',
          );
        }
      }
    }
    return ArrowBoard(arrows: arrows, space: newSpace);
  }

  @override
  List<Object?> get props => [arrows, space];
}

import 'package:equatable/equatable.dart';
import 'arrow.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';

// Aggregate Root: único punto de acceso al estado del tablero de flechas.
class ArrowBoard extends Equatable {
  final List<Arrow> arrows;
  final int cols;
  final int rows;

  const ArrowBoard({
    required this.arrows,
    required this.cols,
    required this.rows,
  });

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

  // Permite a los consumidores distinguir "id ausente" de "salida bloqueada"
  // sin exponer la búsqueda interna ni iterar la lista de arrows fuera del AR.
  bool contains(ArrowId id) => _findById(id) != null;

  /// La flecha con [id], o null. Expone la búsqueda interna como query pública
  /// sin que los consumidores iteren `arrows` fuera del aggregate root.
  Arrow? arrowById(ArrowId id) => _findById(id);

  /// La flecha que ocupa la celda [pos], o null si está vacía. Es la base del
  /// hit-testing por celda (agnóstico de la forma de la flecha).
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

  /// True si alguna celda del cuerpo de [arrow] coincide con una celda ya
  /// ocupada por otra flecha del tablero. Base para impedir que dos flechas
  /// se coloquen superpuestas (cada celda pertenece a una sola flecha).
  bool overlaps(Arrow arrow) {
    // Se consulta el caché total y se descartan las celdas de la PROPIA
    // flecha (la copia que vive en el tablero, si existe): equivale a la
    // antigua reconstrucción "ocupado excluyendo id" sin rehacer el Set.
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
    return arrow
        .exitPath(cols, rows)
        .every((p) => !_occupied.contains(p) || ownCells.contains(p));
  }

  ArrowBoard removeArrow(ArrowId id) {
    return ArrowBoard(
      arrows: arrows.where((a) => a.id != id).toList(),
      cols: cols,
      rows: rows,
    );
  }

  @override
  List<Object?> get props => [arrows, cols, rows];
}

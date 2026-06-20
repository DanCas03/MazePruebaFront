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

  Set<Position> _occupiedExcluding(ArrowId excludeId) {
    final set = <Position>{};
    for (final a in arrows) {
      if (a.id != excludeId) set.addAll(a.cells);
    }
    return set;
  }

  /// True si alguna celda del cuerpo de [arrow] coincide con una celda ya
  /// ocupada por otra flecha del tablero. Base para impedir que dos flechas
  /// se coloquen superpuestas (cada celda pertenece a una sola flecha).
  bool overlaps(Arrow arrow) {
    final occupied = _occupiedExcluding(arrow.id);
    return arrow.cells.any(occupied.contains);
  }

  bool canExit(ArrowId id) {
    final arrow = _findById(id);
    if (arrow == null) return false;
    final occupied = _occupiedExcluding(id);
    return arrow.exitPath(cols, rows).every((p) => !occupied.contains(p));
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

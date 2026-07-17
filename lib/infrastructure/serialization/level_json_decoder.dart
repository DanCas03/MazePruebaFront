import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/entities/level.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/core/exceptions/domain_exception.dart';
import '../../domain/game_core/value_objects/strike_count.dart';
import '../../domain/game_core/space/rect_space.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Parsea el JSON arrow-path del wire contract (CONTEXT-MAP raíz) a un [Level].
/// Inverso de [LevelJsonEncoder]; propiedad golden: encodear el resultado de
/// decodear reproduce el JSON original. ESTRICTO: cualquier desviación del
/// contrato (clave ausente, tipo incorrecto, headDir desconocido, cells vacío o
/// celda malformada) o violación de invariante de dominio lanza [FormatException]
/// con el motivo; el repo la traduce a LevelCorrupted.
class LevelJsonDecoder {
  const LevelJsonDecoder();

  Level decode(Map<String, Object?> json) {
    try {
      return _decodeStrict(json);
    } on DomainException catch (e) {
      // Datos del wire que violan una invariante de dominio = contrato roto.
      throw FormatException('domain invariant violated: ${e.message}');
    }
  }

  Level _decodeStrict(Map<String, Object?> json) {
    final arrows = <Arrow>[
      for (final raw in _list(json, 'arrows')) _arrow(raw),
    ];
    return Level(
      id: LevelId(_string(json, 'levelId')),
      board: ArrowBoard(
        arrows: arrows,
        space: RectSpace(_int(json, 'cols'), _int(json, 'rows')),
      ),
      timeLimitSec: _optionalInt(json, 'timeLimitSec'),
      // Presupuesto de errores opcional (front#83): aditivo/tolerante como
      // timeLimitSec. Ausente ⇒ el default del dominio (dificultad sin cambios);
      // presente pero no-int ⇒ contrato roto (_optionalInt lanza).
      maxErrors: _optionalInt(json, 'maxErrors') ?? StrikeCount.defaultMax,
      // Instrucciones de pintado opcionales (ADR 0004): dato opaco de niveles
      // temáticos. Ausente = campaña. Se valida la FORMA (Map<String,String>);
      // la validez del hex la resuelve el seam de color con fallback (front#67).
      palette: _optionalStringMap(json, 'palette'),
      // Silueta temática opcional (#118): mapa rol→celdas del fill que define
      // la forma jugable de niveles temáticos. Ausente = campaña. La
      // contención (celda dentro de bounds, flechas dentro de la unión) la
      // valida el constructor de Level; su violación se traduce a
      // FormatException en el catch de arriba, mismo patrón que maxErrors/
      // timeLimitSec/arrows vacío.
      silhouette: _optionalSilhouette(json),
    );
  }

  Arrow _arrow(Object? raw) {
    if (raw is! Map) throw const FormatException('arrow must be an object');
    final map = raw.cast<String, Object?>();
    final id = _string(map, 'id');
    final cells = _list(map, 'cells');
    if (cells.isEmpty) {
      throw FormatException('cells must be non-empty (arrow "$id")');
    }
    return Arrow(
      id: ArrowId(id),
      headDirection: _direction(_string(map, 'headDir')),
      cells: [for (final cell in cells) _position(cell, id)],
      // Rol de pintado opcional (ADR 0004): dato opaco, ausente en campaña.
      paintRole: _optionalString(map, 'paintRole'),
    );
  }

  Position _position(Object? cell, String arrowId) {
    if (cell is! List || cell.length != 2) {
      throw FormatException('cell must be a [row, col] pair (arrow "$arrowId")');
    }
    final row = cell[0];
    final col = cell[1];
    if (row is! int || col is! int) {
      throw FormatException('cell coords must be ints (arrow "$arrowId")');
    }
    return Position(row: row, col: col);
  }

  Direction _direction(String headDir) {
    for (final d in Direction.values) {
      if (d.name == headDir) return d;
    }
    throw FormatException('unknown headDir "$headDir"');
  }

  List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('missing or non-list "$key"');
    return value;
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('missing or non-string "$key"');
    return value;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('missing or non-int "$key"');
    return value;
  }

  int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('"$key" must be an int when present');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('"$key" must be a string when present');
    }
    return value;
  }

  Map<String, String>? _optionalStringMap(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('"$key" must be an object when present');
    }
    final result = <String, String>{};
    value.forEach((k, v) {
      if (k is! String || v is! String) {
        throw FormatException('"$key" must map strings to strings');
      }
      result[k] = v;
    });
    return result;
  }

  Map<String, Set<Position>>? _optionalSilhouette(Map<String, Object?> json) {
    final value = json['silhouette'];
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('"silhouette" must be an object when present');
    }
    final result = <String, Set<Position>>{};
    value.forEach((role, cells) {
      if (role is! String) {
        throw FormatException('"silhouette" role must be a string, got $role');
      }
      if (cells is! List) {
        throw FormatException('"silhouette" region "$role" must be a list of cells');
      }
      result[role] = {
        for (final cell in cells) _position(cell, 'silhouette:$role'),
      };
    });
    return result;
  }
}

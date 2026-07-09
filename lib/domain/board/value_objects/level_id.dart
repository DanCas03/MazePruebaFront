import 'package:equatable/equatable.dart';
import '../../core/exceptions/invalid_level_id_exception.dart';

class LevelId extends Equatable {
  final String value;
  LevelId(this.value) {
    if (value.trim().isEmpty) throw InvalidLevelIdException('LevelId cannot be blank');
  }

  /// Número de nivel para escalar dificultad y sembrar la generación.
  /// Fallback a 1 si el valor no es numérico (ids siempre son "1", "2", …).
  int get number => int.tryParse(value) ?? 1;

  @override
  List<Object?> get props => [value];
}

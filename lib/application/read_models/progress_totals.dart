import 'package:equatable/equatable.dart';

import '../../domain/board/value_objects/level_progress.dart';

/// Read model agregado para el panel de cuenta (front#78): totales de progreso
/// derivados del progreso local por nivel. Vive en `application/` porque es una
/// vista para la UI (no una regla de dominio): reduce la lista de [LevelProgress]
/// a dos contadores, sin exponer la fuente (Hive) a la presentación.
class ProgressTotals extends Equatable {
  /// Suma de las mejores estrellas por nivel (`bestStars ?? 0`).
  final int totalStars;

  /// Número de niveles marcados como completados.
  final int completedLevels;

  const ProgressTotals({
    required this.totalStars,
    required this.completedLevels,
  });

  /// Reduce el progreso persistido a los totales. Un nivel sin estrellas
  /// (`bestStars == null`) aporta 0; `completed` cuenta con independencia de
  /// las estrellas (un nivel puede completarse sin lograr ninguna).
  factory ProgressTotals.from(List<LevelProgress> progress) {
    var stars = 0;
    var completed = 0;
    for (final p in progress) {
      stars += p.bestStars ?? 0;
      if (p.completed) completed++;
    }
    return ProgressTotals(totalStars: stars, completedLevels: completed);
  }

  @override
  List<Object?> get props => [totalStars, completedLevels];
}

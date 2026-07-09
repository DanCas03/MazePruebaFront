import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';

/// Deriva un índice de color ESTABLE por flecha a partir de su [ArrowId].
///
/// El color es responsabilidad de presentación (el dominio no lo conoce). Los
/// ids generados tienen forma `arrow-N`: se parsea el sufijo para obtener un
/// arcoíris secuencial; si el id no es numérico se usa un hash determinista.
/// El índice es estable ante remociones (ligado a la identidad, no a la
/// posición en la lista de flechas).
int arrowColorIndex(ArrowId id) {
  final value = id.value;
  final dash = value.lastIndexOf('-');
  final suffix = dash >= 0 ? value.substring(dash + 1) : value;
  final parsed = int.tryParse(suffix);
  final base = parsed ?? value.hashCode.abs();
  return base % AppColors.arrowPalette.length;
}

/// Resuelve el [Color] de una flecha a partir de su [ArrowId].
Color arrowColorFor(ArrowId id) => AppColors.arrowColor(arrowColorIndex(id));

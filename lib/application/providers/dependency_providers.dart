// lib/application/providers/dependency_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../core/aspects/i_logger_service.dart';

/// Providers de los PUERTOS de la aplicación (DIP).
///
/// Clean Architecture: están tipados con las INTERFACES del dominio/aplicación,
/// no con clases concretas. Se declaran como placeholders y se sobreescriben en
/// `main.dart` (raíz de composición) con las implementaciones de la Capa 4.
/// Gracias a esto, la capa de Aplicación nunca importa `infrastructure/`.
final levelGeneratorProvider = Provider<ILevelGenerator>(
  (ref) => throw UnimplementedError(
    'levelGeneratorProvider debe sobreescribirse en main.dart',
  ),
);

final levelProgressRepositoryProvider = Provider<ILevelProgressRepository>(
  (ref) => throw UnimplementedError(
    'levelProgressRepositoryProvider debe sobreescribirse en main.dart',
  ),
);

final loggerServiceProvider = Provider<ILoggerService>(
  (ref) => throw UnimplementedError(
    'loggerServiceProvider debe sobreescribirse en main.dart',
  ),
);

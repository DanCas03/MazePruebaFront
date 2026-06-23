import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../core/aspects/logger_service_adapter.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../infrastructure/data_sources/local/hive_level_progress_data_source.dart';
import '../../infrastructure/generators/graph_board_generator.dart';
import '../../infrastructure/repositories/hive_progress_repository.dart';

/// Composition root (DIP): unico lugar donde se instancian clases de
/// `infrastructure/`. La presentation y application dependen de abstracciones
/// (`ILoggerService`, `ILevelProgressRepository`, `ILevelGenerator`) y reciben
/// las impls concretas por inyeccion via estos providers Riverpod.

// AOP logger — singleton para toda la app.
final loggerServiceProvider = Provider<ILoggerService>(
  (_) => LoggerServiceAdapter(),
);

// Infraestructura Hive — DataSource separado del Repository (Petros pattern).
final hiveDataSourceProvider = Provider<HiveLocalDataSource>(
  (_) => HiveLocalDataSource(),
);

final levelProgressRepositoryProvider = Provider<ILevelProgressRepository>(
  (ref) => HiveProgressRepository(ref.watch(hiveDataSourceProvider)),
);

final levelGeneratorProvider = Provider<ILevelGenerator>(
  (_) => GraphBoardGenerator(),
);

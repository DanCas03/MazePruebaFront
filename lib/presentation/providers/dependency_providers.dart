import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/audio/i_audio_service.dart';
import '../../application/audio/silent_audio_service.dart';
import '../../application/use_cases/sync_progress_use_case.dart';
import '../../core/aspects/i_logger_service.dart';
import '../../core/aspects/logger_service_adapter.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/repositories/i_remote_progress_repository.dart';
import '../../domain/board/services/progress_reconciler.dart';
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

// Audio (front#5) — Facade+Singleton tras el puerto IAudioService, decorado con
// logging (2o aspecto AOP). El default es el Null Object silencioso para que las
// capas y los tests de widget funcionen sin componer el audio real (que necesita
// el box Hive abierto y players nativos); `main` lo sobreescribe con el
// AudioService real ya inicializado.
final audioServiceProvider = Provider<IAudioService>(
  (_) => const SilentAudioService(),
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

// front#18: el repo remoto necesita el Dio compuesto en main (con el token
// interceptor); por eso su default falla y main.dart lo sobreescribe (DIP),
// igual que authRepositoryProvider.
final remoteProgressRepositoryProvider = Provider<IRemoteProgressRepository>(
  (_) => throw UnimplementedError(
    'remoteProgressRepositoryProvider must be overridden in main with composed Dio',
  ),
);

final progressReconcilerProvider = Provider<ProgressReconciler>(
  (_) => ProgressReconciler(),
);

final syncProgressUseCaseProvider = Provider<SyncProgressUseCase>(
  (ref) => SyncProgressUseCase(
    ref.watch(remoteProgressRepositoryProvider),
    ref.watch(levelProgressRepositoryProvider),
    ref.watch(progressReconcilerProvider),
    ref.watch(loggerServiceProvider),
  ),
);

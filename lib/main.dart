import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'l10n/app_localizations.dart';

import 'application/providers/leaderboard_providers.dart';
import 'application/providers/level_catalog_provider.dart';
import 'application/state/auth_controller.dart';
import 'application/state/game_controller.dart';
import 'application/commands/command_invoker.dart';
import 'application/use_cases/remove_arrow_use_case.dart';
import 'application/state/auth_form_controller.dart';
import 'application/use_cases/restore_session_use_case.dart';
import 'application/use_cases/submit_score_use_case.dart';
import 'core/aspects/logger_service_adapter.dart';
import 'core/auth/auth_gate.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'hive_registrar.g.dart';
import 'infrastructure/audio/audio_service.dart';
import 'infrastructure/audio/audioplayers_backend.dart';
import 'infrastructure/audio/hive_audio_settings_store.dart';
import 'infrastructure/audio/logging_audio_decorator.dart';
import 'infrastructure/data_sources/local/level_cache_data_source.dart';
import 'infrastructure/data_sources/local/secure_token_data_source.dart';
import 'infrastructure/data_sources/remote/auth_remote_data_source.dart';
import 'infrastructure/data_sources/remote/leaderboard_remote_data_source.dart';
import 'infrastructure/data_sources/remote/level_remote_data_source.dart';
import 'infrastructure/data_sources/remote/remote_progress_data_source.dart';
import 'infrastructure/models/level_progress_hive_model.dart';
import 'infrastructure/repositories/in_memory_session_token_store.dart';
import 'infrastructure/repositories/remote_auth_repository.dart';
import 'infrastructure/repositories/remote_leaderboard_repository.dart';
import 'infrastructure/repositories/remote_level_repository.dart';
import 'infrastructure/repositories/remote_progress_repository.dart';
import 'infrastructure/repositories/secure_auth_token_repository.dart';
import 'infrastructure/serialization/level_json_decoder.dart';
import 'infrastructure/time/system_ticker.dart';
import 'presentation/providers/dependency_providers.dart';

/// Composition root: inicializa Hive y conecta las dependencias concretas de
/// GameController via ProviderScope.overrides (DIP). Ninguna capa interna
/// conoce las implementaciones; solo main puede ver infraestructura.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<LevelProgressHiveModel>('level_progress');
  // front#8: box sin tipar para el JSON crudo de los niveles remotos (catálogo
  // + un entry por nivel). Sin TTL: online siempre refetchea (network-first).
  await Hive.openBox(LevelCacheDataSource.boxName);
  // front#5: box sin tipar para el estado de mute del audio (3 booleanos).
  final audioSettingsBox = await Hive.openBox(HiveAudioSettingsStore.boxName);

  // Composicion del subsistema de audio (front#5): Facade+Singleton tras el
  // puerto, decorado con logging (AOP). init() carga el mute persistido antes
  // de que la UI lo lea; el Null Object del provider queda sustituido aqui.
  final audioService = LoggingAudioDecorator(
    AudioService(
      AudioplayersBackend(),
      HiveAudioSettingsStore(audioSettingsBox),
    ),
    LoggerServiceAdapter(),
  );
  await audioService.init();

  // Composición del lazo de auth (front#14): el token se persiste en el
  // almacenamiento seguro del SO. Se inyecta por constructor (DIP) al
  // AuthController, cuyo build() restaura la sesión (auto-login) cuando el
  // guard de ruta (front#15) lo lea por primera vez.
  final tokenStorage = SecureAuthTokenRepository(
    SecureTokenDataSource(const FlutterSecureStorage()),
  );

  // front#16: fuente única del token vivo (memoria), compartida por el
  // interceptor y el AuthController. Firma las llamadas autenticadas también en
  // sesiones `remember:false`.
  final sessionTokenStore = InMemorySessionTokenStore();

  // Cliente HTTP con la URL base configurable y el interceptor de token que lee
  // la sesión viva (front#15/#16).
  final dio = DioClient.create(sessionTokenStore);
  final authRepository = RemoteAuthRepository(AuthRemoteDataSource(dio));

  // front#8: repo remoto de niveles (network-first + caché) con el mismo Dio
  // firmado y la box levels_cache abierta arriba. Alimenta el Catálogo y la
  // carga de partida; DioException muere dentro del repo.
  final levelRepository = RemoteLevelRepository(
    LevelRemoteDataSource(dio),
    LevelCacheDataSource(),
    const LevelJsonDecoder(),
    LoggerServiceAdapter(),
  );

  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => AuthController(
              tokenStorage, RestoreSessionUseCase(tokenStorage), sessionTokenStore),
        ),
        // GameController compuesto con sus dependencias concretas (DIP). Ahora
        // carga los niveles oficiales vía ILevelRepository (front#8) en lugar de
        // generarlos; incluye el reloj real (SystemTicker) para los niveles con
        // límite (front#11).
        gameControllerProvider.overrideWith(
          () => GameController(
            levelRepository,
            RemoveArrowUseCase(),
            CommandInvoker(),
            const SystemTicker(),
          ),
        ),
        // front#15: repo remoto de auth compuesto aquí (DIP); las capas
        // internas solo conocen el puerto IAuthRepository.
        authRepositoryProvider.overrideWithValue(authRepository),
        // front#18: repo remoto de progreso compuesto con el mismo Dio (token
        // interceptor). Las capas internas solo conocen el puerto.
        remoteProgressRepositoryProvider.overrideWithValue(
          RemoteProgressRepository(RemoteProgressDataSource(dio)),
        ),
        // front#8: el puerto de niveles y el Catálogo comparten la misma
        // instancia del repo remoto compuesta arriba.
        levelRepositoryProvider.overrideWithValue(levelRepository),
        levelCatalogProvider.overrideWith(
          () => LevelCatalogNotifier(levelRepository, LoggerServiceAdapter()),
        ),
        // front#5: audio real (Facade+Singleton decorado) sustituye al Null
        // Object; las capas internas solo conocen el puerto IAudioService.
        audioServiceProvider.overrideWithValue(audioService),
        // front#16: envío de score compuesto con el mismo Dio firmado. Las
        // capas internas solo conocen el puerto ILeaderboardRepository.
        submitScoreUseCaseProvider.overrideWithValue(
          SubmitScoreUseCase(
            RemoteLeaderboardRepository(LeaderboardRemoteDataSource(dio)),
            LoggerServiceAdapter(),
          ),
        ),
      ],
      child: const ArrowMazeApp(),
    ),
  );
}

class ArrowMazeApp extends StatelessWidget {
  const ArrowMazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // onGenerateTitle: el título del task switcher del SO se localiza con el
      // locale activo (front#4). `title` estático se reemplaza por esta variante
      // reactiva al idioma.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // ThemeMode.system: el SO elige claro u oscuro; ambos temas estan
      // definidos en AppTheme para una experiencia coherente en ambos modos.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // i18n (front#4): delegates generados por gen-l10n (incluyen los Global*
      // de Flutter para Material/Widgets/Cupertino). El SO elige es o en según
      // el locale del dispositivo; español primero como idioma primario de la
      // app (fallback para locales no soportados).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

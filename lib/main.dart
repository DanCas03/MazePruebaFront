import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'l10n/app_localizations.dart';

import 'application/providers/leaderboard_providers.dart';
import 'application/state/auth_controller.dart';
import 'application/state/game_controller.dart';
import 'application/state/level_selection_controller.dart';
import 'application/commands/command_invoker.dart';
import 'application/use_cases/get_leaderboard_use_case.dart';
import 'application/use_cases/remove_arrow_use_case.dart';
import 'application/state/auth_form_controller.dart';
import 'application/use_cases/restore_session_use_case.dart';
import 'application/use_cases/submit_score_use_case.dart';
import 'core/aspects/logger_service_adapter.dart';
import 'domain/board/services/tier_gating.dart';
import 'core/auth/auth_gate.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/router/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'hive_registrar.g.dart';
import 'infrastructure/audio/audio_service.dart';
import 'infrastructure/audio/audioplayers_backend.dart';
import 'infrastructure/audio/hive_audio_settings_store.dart';
import 'infrastructure/audio/logging_audio_decorator.dart';
import 'infrastructure/generators/graph_board_generator.dart';
import 'infrastructure/data_sources/local/hive_level_progress_data_source.dart';
import 'infrastructure/data_sources/local/secure_token_data_source.dart';
import 'infrastructure/data_sources/remote/auth_remote_data_source.dart';
import 'infrastructure/data_sources/remote/leaderboard_remote_data_source.dart';
import 'infrastructure/data_sources/remote/remote_progress_data_source.dart';
import 'infrastructure/models/level_progress_hive_model.dart';
import 'infrastructure/repositories/hive_progress_repository.dart';
import 'infrastructure/repositories/in_memory_session_token_store.dart';
import 'infrastructure/repositories/remote_auth_repository.dart';
import 'infrastructure/repositories/remote_leaderboard_repository.dart';
import 'infrastructure/repositories/remote_progress_repository.dart';
import 'infrastructure/repositories/static_level_catalog.dart';
import 'infrastructure/repositories/secure_auth_token_repository.dart';
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

  // #20: una sola composición del repo de progreso local (mismo box Hive ya
  // abierto), compartida por el sync (front#18) y por el selector de nivel, en
  // vez de instanciar dos `HiveProgressRepository` equivalentes.
  final levelProgressRepository =
      HiveProgressRepository(HiveLocalDataSource());

  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => AuthController(
              tokenStorage, RestoreSessionUseCase(tokenStorage), sessionTokenStore),
        ),
        // GameController compuesto con sus dependencias concretas (DIP). Incluye
        // el reloj real (SystemTicker) que dispara la cuenta atrás de los niveles
        // con límite (front#11). Sin este override, entrar a la partida lanzaría
        // UnimplementedError (regresión de BUG-2 al cablear auth).
        gameControllerProvider.overrideWith(
          () => GameController(
            GraphBoardGenerator(),
            RemoveArrowUseCase(),
            CommandInvoker(),
            const SystemTicker(),
          ),
        ),
        // #18/#20: el repo de progreso local se comparte (una sola instancia)
        // entre el sync y el selector; se sobreescribe el provider para que
        // ambos consumidores usen exactamente la misma composición.
        levelProgressRepositoryProvider.overrideWithValue(levelProgressRepository),
        // #20: selección de nivel compuesta con el catálogo estático curado, el
        // repo de progreso local compartido y el gating por Tier. Sin este
        // override, abrir el selector lanzaría UnimplementedError.
        levelSelectionControllerProvider.overrideWith(
          () => LevelSelectionController(
            const StaticLevelCatalog(),
            levelProgressRepository,
            const TierGating(),
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
        // front#17: lectura del ranking compuesta con el mismo Dio (el GET es
        // público, pero se reutiliza el cliente HTTP). Las capas internas solo
        // conocen el puerto ILeaderboardRepository.
        getLeaderboardUseCaseProvider.overrideWithValue(
          GetLeaderboardUseCase(
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
      // #20: el selector de nivel usa `RouteAware` para recomponer su progreso
      // al ser revelado tras un `pop` (volver de una partida).
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
    );
  }
}

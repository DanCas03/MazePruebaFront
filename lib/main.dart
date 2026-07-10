import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'application/state/auth_controller.dart';
import 'application/state/game_controller.dart';
import 'application/commands/command_invoker.dart';
import 'application/use_cases/remove_arrow_use_case.dart';
import 'application/state/auth_form_controller.dart';
import 'application/use_cases/restore_session_use_case.dart';
import 'core/auth/auth_gate.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'hive_registrar.g.dart';
import 'infrastructure/generators/graph_board_generator.dart';
import 'infrastructure/data_sources/local/secure_token_data_source.dart';
import 'infrastructure/data_sources/remote/auth_remote_data_source.dart';
import 'infrastructure/models/level_progress_hive_model.dart';
import 'infrastructure/repositories/remote_auth_repository.dart';
import 'infrastructure/repositories/secure_auth_token_repository.dart';
import 'infrastructure/time/system_ticker.dart';

/// Composition root: inicializa Hive y conecta las dependencias concretas de
/// GameController via ProviderScope.overrides (DIP). Ninguna capa interna
/// conoce las implementaciones; solo main puede ver infraestructura.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<LevelProgressHiveModel>('level_progress');

  // Composición del lazo de auth (front#14): el token se persiste en el
  // almacenamiento seguro del SO. Se inyecta por constructor (DIP) al
  // AuthController, cuyo build() restaura la sesión (auto-login) cuando el
  // guard de ruta (front#15) lo lea por primera vez.
  final tokenStorage = SecureAuthTokenRepository(
    SecureTokenDataSource(const FlutterSecureStorage()),
  );

  // Cliente HTTP con la URL base configurable y el interceptor de token (front#15).
  final dio = DioClient.create(tokenStorage);
  final authRepository = RemoteAuthRepository(AuthRemoteDataSource(dio));

  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => AuthController(tokenStorage, RestoreSessionUseCase(tokenStorage)),
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
        // front#15: repo remoto de auth compuesto aquí (DIP); las capas
        // internas solo conocen el puerto IAuthRepository.
        authRepositoryProvider.overrideWithValue(authRepository),
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
      title: 'Arrow Maze',
      // ThemeMode.system: el SO elige claro u oscuro; ambos temas estan
      // definidos en AppTheme para una experiencia coherente en ambos modos.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

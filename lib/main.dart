import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'application/providers/dependency_providers.dart';
import 'core/aspects/logger_service_adapter.dart';
import 'core/theme/app_theme.dart';
import 'infrastructure/generators/graph_board_generator.dart';
import 'infrastructure/models/level_progress_hive_model.dart';
import 'infrastructure/repositories_impl/hive_progress_adapter.dart';
import 'presentation/home/screens/home_screen.dart';

/// Punto de entrada y RAÍZ DE COMPOSICIÓN de la app.
///
/// Único lugar que conoce la Capa 4 (infraestructura): inicializa Hive e
/// inyecta las implementaciones concretas sobreescribiendo los providers de los
/// puertos. El resto de capas permanece desacoplado de las tecnologías.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(LevelProgressHiveModelAdapter());
  final progressBox =
      await Hive.openBox<LevelProgressHiveModel>('level_progress');

  runApp(
    ProviderScope(
      overrides: [
        levelGeneratorProvider.overrideWithValue(GraphBoardGenerator()),
        levelProgressRepositoryProvider
            .overrideWithValue(HiveProgressAdapter(progressBox)),
        loggerServiceProvider.overrideWithValue(LoggerServiceAdapter()),
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

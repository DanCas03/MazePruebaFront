import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'hive_registrar.g.dart';
import 'infrastructure/models/level_progress_hive_model.dart';

/// Composition root de la app: inicializa Hive, registra los TypeAdapters
/// (via la extension generada `registerAdapters`) y abre el box de progreso
/// antes de levantar el ProviderScope. Mantener este wiring en `main` deja la
/// capa de presentacion libre de detalles de infraestructura (DIP).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<LevelProgressHiveModel>('level_progress');
  runApp(const ProviderScope(child: ArrowMazeApp()));
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
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Cuadricula de seleccion de nivel (12 niveles). Cada celda es un panel
/// glassmorphism que navega a la partida. Pantalla de pura presentacion:
/// la lista de niveles es estatica de momento (la fuente real llegara con el
/// repositorio de progreso, ILevelProgressRepository).
class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  static const int _levelCount = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).selectLevel),
        backgroundColor: surface,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _levelCount,
        itemBuilder: (context, i) => InkWell(
          onTap: () => Navigator.pushNamed(
                context,
                AppRouter.game,
                arguments: LevelId('${i + 1}'),
              ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              // Panel glassmorphism: relleno translucido + borde sutil.
              color: glassFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glassBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: onBackground,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

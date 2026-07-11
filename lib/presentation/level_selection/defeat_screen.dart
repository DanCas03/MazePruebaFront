import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Argumentos de la ruta de derrota: el [levelId] permite reintentar el mismo
/// nivel y [moves]/[strikes] son solo para mostrar el resumen de la partida.
typedef DefeatArgs = ({LevelId levelId, int moves, int strikes});

/// Pantalla de derrota: se muestra al entrar en `GameLost` (5º choque). El CTA
/// principal reintenta el nivel recargando la pantalla de juego con el mismo
/// [LevelId] (generación determinista ⇒ mismo tablero); el secundario vuelve
/// al selector de niveles limpiando la pila.
class DefeatScreen extends StatelessWidget {
  const DefeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as DefeatArgs?;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_dissatisfied,
                  color: AppColors.error, size: 80),
              const SizedBox(height: 16),
              Text(
                l10n.defeatTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.defeatSummary(args?.moves ?? 0, args?.strikes ?? 0),
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: args == null
                    ? null
                    : () => Navigator.pushReplacementNamed(
                          context,
                          AppRouter.game,
                          arguments: args.levelId,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      isDark ? AppColors.background : AppColors.lightSurface,
                ),
                child: Text(l10n.retry),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.levelSelection,
                  (_) => false,
                ),
                child: Text(
                  l10n.backToLevels,
                  style: TextStyle(color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

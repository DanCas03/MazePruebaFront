import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Pantalla de victoria: confirma el tablero limpiado y muestra el numero de
/// movimientos recibido como `arguments` de la ruta. CTA regresa al selector
/// de niveles limpiando la pila de navegacion.
class VictoryScreen extends StatelessWidget {
  const VictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final moves = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
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
              const Icon(Icons.star, color: AppColors.success, size: 80),
              const SizedBox(height: 16),
              Text(
                l10n.victoryTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.victoryMoves(moves),
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.levelSelection,
                  (_) => false,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      isDark ? AppColors.background : AppColors.lightSurface,
                ),
                child: Text(l10n.backToLevels),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Pantalla inicial de Arrow Maze: titulo neon, tagline y CTA "Play".
/// Solo presentacion: navega por nombre de ruta (AppRouter) sin conocer la
/// clase destino, manteniendo el desacople entre pantallas.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Arrow Maze',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  // Glow neon sutil para dar profundidad al titulo.
                  shadows: [
                    Shadow(color: primary.withValues(alpha: 0.5), blurRadius: 24),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Clear the board',
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 64),
              FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.levelSelection),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      isDark ? AppColors.background : AppColors.lightSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
                child: const Text('Play', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

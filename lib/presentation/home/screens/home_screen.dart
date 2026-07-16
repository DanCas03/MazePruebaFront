import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/account_panel.dart';

/// Pantalla inicial de Arrow Maze: logo flotante, titulo, tagline y CTA.
/// Solo presentacion: navega por nombre de ruta (AppRouter) sin conocer la
/// clase destino, manteniendo el desacople entre pantallas. Es `ConsumerWidget`
/// para poder abrir el panel de cuenta (front#78), que consume providers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: [AppColors.background, AppColors.backgroundDeep],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // front#78: acceso a la cuenta (perfil + cerrar sesión). Espejo
              // top-left del icono de ajustes (top-right).
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.account_circle,
                      color: AppColors.onSurfaceMuted),
                  tooltip: l10n.accountTooltip,
                  onPressed: () => AccountPanel.show(context),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.settings,
                      color: AppColors.onSurfaceMuted),
                  tooltip: l10n.settingsTitle,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.settings),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LogoArrows(),
                const SizedBox(height: 28),
                Text(
                  l10n.appTitle.toUpperCase(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeTagline,
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 15),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.levelSelection),
                  child: Text(
                    l10n.homePlay,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // front#100: acceso a la sección temática (niveles con silueta).
                // Secundario (contorneado) como el generador; comparte el patrón.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.themed),
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(
                    l10n.homeThemed,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // front#37: acceso al generador de tableros efímeros. Secundario
                // (contorneado) frente al CTA primario de la campaña.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.generate),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    l10n.generateBoard,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cluster decorativo de flechas para el logo, con flotación perpetua sutil.
/// Un único [AnimationController] en bucle (`repeat`) gobierna las tres cápsulas;
/// cada una "flota" con una senoidal desfasada (fases 0, 2.1, 4.2 rad) para un
/// movimiento continuo y fluido en vez de una entrada de una sola pasada.
class _LogoArrows extends StatefulWidget {
  const _LogoArrows();

  @override
  State<_LogoArrows> createState() => _LogoArrowsState();
}

class _LogoArrowsState extends State<_LogoArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 140,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final base = _controller.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              _bar(36, 2, AppColors.arrowPalette[1], Icons.arrow_forward,
                  math.sin(base)),
              _bar(-36, 28, AppColors.arrowPalette[0], Icons.arrow_downward,
                  math.sin(base + 2.1)),
              _bar(2, -28, AppColors.arrowPalette[5], Icons.arrow_upward,
                  math.sin(base + 4.2)),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double dx, double dy, Color color, IconData icon, double bob) {
    return Transform.translate(
      offset: Offset(dx, dy + bob * 5),
      child: Container(
        width: 66,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 18),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

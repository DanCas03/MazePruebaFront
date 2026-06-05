import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../level_selection/screens/level_selection_screen.dart';

/// Menú principal. Presentación pura, sin lógica de negocio.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LogoArrows(),
                const SizedBox(height: 28),
                Text(
                  'ARROW MAZE',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Despeja el tablero. Saca cada flecha.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.seed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelSelectionScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'JUGAR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cluster decorativo de flechas para el logo, con flotación perpetua sutil.
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

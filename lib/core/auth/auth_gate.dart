import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/state/auth_controller.dart';
import '../../application/state/auth_state.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../theme/app_colors.dart';

/// Guard de ruta reactivo (Observer). Como la app usa Navigator 1.0 (sin
/// go_router), el guard vive en el `home` del MaterialApp: observa AuthState y
/// decide entre login y el flujo de juego. Las rutas nombradas de juego siguen
/// resolviéndose por onGenerateRoute dentro del subtree autenticado.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (_, __) => const LoginScreen(),
      data: (state) => switch (state) {
        Authenticated() => const HomeScreen(),
        Unauthenticated() => const LoginScreen(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.lightBackground,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

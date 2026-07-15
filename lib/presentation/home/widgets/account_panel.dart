import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/account_providers.dart';
import '../../../application/read_models/progress_totals.dart';
import '../../../application/state/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/entities/user_profile.dart';
import '../../../l10n/app_localizations.dart';

/// Panel de cuenta (front#78): bottom sheet con el perfil del jugador
/// (username/email), sus totales de progreso local y la acción de cerrar sesión.
///
/// Solo presentación: consume providers de `application/` (`currentUserProvider`,
/// `progressTotalsProvider`, `authControllerProvider`) sin conocer dominio ni
/// infraestructura. El cierre de sesión delega en el `AuthController`; el
/// `AuthGate` conmuta a `LoginScreen` al observar `Unauthenticated`.
class AccountPanel extends ConsumerWidget {
  const AccountPanel({super.key});

  /// Abre el panel como modal bottom sheet. Punto de entrada único usado por
  /// el icono de cuenta de `HomeScreen`.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AccountPanel(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asa de arrastre.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.accountTitle,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              // El perfil puede cargar/fallar; los totales son locales y viven
              // en su propia sección para no depender de la llamada de red.
              user.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _ProfileError(l10n: l10n, ref: ref),
                data: (profile) => _ProfileHeader(profile: profile),
              ),
              const SizedBox(height: 20),
              const _ProgressTotalsRow(),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pill,
                  foregroundColor: AppColors.onBackground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  // Lee el notifier ANTES de cerrar el sheet (tras el pop el
                  // context deja de tener el ProviderScope del subtree). Cierra
                  // el modal y luego cierra sesión: el AuthGate reacciona al
                  // nuevo estado y muestra LoginScreen debajo.
                  final auth = ref.read(authControllerProvider.notifier);
                  Navigator.of(context).pop();
                  auth.signOut();
                },
                icon: const Icon(Icons.logout, size: 20),
                label: Text(
                  l10n.accountSignOut,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera con avatar, username y email del perfil cargado.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.pill,
          child: Icon(Icons.account_circle,
              size: 40, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.username.value,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                profile.email.value,
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mensaje de error del perfil con reintento (invalida el provider autoDispose).
class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.l10n, required this.ref});

  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.accountLoadError,
            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
        ),
        TextButton(
          onPressed: () => ref.invalidate(currentUserProvider),
          child: Text(l10n.accountRetry),
        ),
      ],
    );
  }
}

/// Fila de totales de progreso (estrellas + niveles completados), derivada del
/// progreso local. Se oculta mientras carga o si falla (dato secundario).
class _ProgressTotalsRow extends ConsumerWidget {
  const _ProgressTotalsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final totals = ref.watch(progressTotalsProvider);
    return totals.maybeWhen(
      data: (ProgressTotals t) => Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.star_rounded,
              color: AppColors.victory,
              label: l10n.accountStarsTotal(t.totalStars),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatChip(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              label: l10n.accountLevelsCompleted(t.completedLevels),
            ),
          ),
        ],
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.pill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

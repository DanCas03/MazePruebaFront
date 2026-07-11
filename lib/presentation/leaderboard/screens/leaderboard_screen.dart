import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/leaderboard_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/board/value_objects/level_id.dart';
import '../../../domain/leaderboard/entities/leaderboard_entry.dart';

/// Pantalla del ranking de un nivel (front#17). Consume `leaderboardProvider`
/// (capa application) y pinta los tres estados de `AsyncValue`: carga, error
/// (con reintento) y datos. La lista llega ordenada por score desc del back, así
/// que el rango es la posición (índice + 1). Pura presentación: no conoce Dio ni
/// el dominio de red, solo el provider.
class LeaderboardScreen extends ConsumerWidget {
  final LevelId levelId;
  const LeaderboardScreen({super.key, required this.levelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final async = ref.watch(leaderboardProvider(levelId.value));

    return Scaffold(
      appBar: AppBar(
        title: Text('Ranking · Nivel ${levelId.value}'),
        backgroundColor: surface,
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            onRetry: () =>
                ref.invalidate(leaderboardProvider(levelId.value)),
          ),
          data: (entries) => entries.isEmpty
              ? const _EmptyState()
              : _LeaderboardList(entries: entries),
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _LeaderboardList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      // El rango es posicional: el back ya devuelve ordenado por score desc.
      itemBuilder: (context, i) =>
          _LeaderboardTile(rank: i + 1, entry: entries[i]),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _LeaderboardTile({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank <= 3 ? AppColors.victory : muted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userId,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                _StarsRow(count: entry.stars.value),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${entry.score.value}',
            style: TextStyle(
              color: onBackground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de estrellas ganadas (1–3), rellenas hasta [count].
class _StarsRow extends StatelessWidget {
  final int count;
  const _StarsRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < count ? Icons.star : Icons.star_border,
          size: 14,
          color: AppColors.victory,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: muted),
          const SizedBox(height: 16),
          Text(
            'Aún no hay puntajes en este nivel.\n¡Sé el primero!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar el ranking.',
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/leaderboard_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/leaderboard/entities/global_leaderboard.dart';
import '../../../l10n/app_localizations.dart';

/// Pantalla del Leaderboard general (ADR 0006): ranking global de jugadores
/// por total de puntos de campaña, con podio para el top 3, lista para el
/// resto y la fila propia siempre visible — resaltada dentro del top o
/// anclada abajo si queda fuera ("sin clasificar" si aún no puntúa).
/// Pura presentación: consume `globalLeaderboardProvider` y pinta los tres
/// estados de `AsyncValue` (carga / error con reintento / datos).
class GlobalLeaderboardScreen extends ConsumerWidget {
  const GlobalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final async = ref.watch(globalLeaderboardProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.globalLeaderboardTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        // Mismo fondo radial que Home: la pantalla es una extensión del menú
        // principal, no un formulario — continuidad visual deliberada.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.1,
            colors: isDark
                ? const [AppColors.background, AppColors.backgroundDeep]
                : const [
                    AppColors.lightBackground,
                    AppColors.lightBackgroundDeep,
                  ],
          ),
        ),
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _ErrorState(
              onRetry: () => ref.invalidate(globalLeaderboardProvider),
            ),
            data: (board) => board.top.isEmpty
                ? const _EmptyState()
                : _GlobalLeaderboardBody(board: board),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo con datos: subtítulo + podio + lista scrolleable (pull-to-refresh) y
/// la fila propia anclada bajo la lista cuando no aparece en el top.
class _GlobalLeaderboardBody extends ConsumerWidget {
  final GlobalLeaderboard board;
  const _GlobalLeaderboardBody({required this.board});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    final podium = board.top.take(3).toList();
    final rest = board.top.skip(3).toList();
    final meRank = board.me?.rank;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(globalLeaderboardProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  l10n.globalLeaderboardSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 20),
                _Podium(entries: podium, meRank: meRank),
                if (rest.isNotEmpty) const SizedBox(height: 20),
                for (final entry in rest) ...[
                  _RankingTile(entry: entry, isMe: entry.rank == meRank),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        if (board.me != null && !board.meIsInTop)
          _AnchoredMeBar(me: board.me!)
        else if (board.me == null)
          const _UnrankedFooter(),
      ],
    );
  }
}

/// Podio del top 3: el nº 1 al centro y elevado, flanqueado por el 2 y el 3.
/// Aparece con un fade+lift de una sola pasada (sin bucles: test-friendly).
class _Podium extends StatelessWidget {
  final List<GlobalLeaderboardEntry> entries;
  final int? meRank;
  const _Podium({required this.entries, required this.meRank});

  @override
  Widget build(BuildContext context) {
    // Orden visual 2-1-3; con menos de 3 entradas se pinta lo que haya.
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _PodiumSpot(
                    entry: second,
                    medal: AppColors.medalSilver,
                    avatarSize: 58,
                    isMe: second.rank == meRank,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: first != null
                ? _PodiumSpot(
                    entry: first,
                    medal: AppColors.medalGold,
                    avatarSize: 74,
                    crowned: true,
                    isMe: first.rank == meRank,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: third != null
                ? _PodiumSpot(
                    entry: third,
                    medal: AppColors.medalBronze,
                    avatarSize: 58,
                    isMe: third.rank == meRank,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Un puesto del podio: avatar-inicial con anillo del color de la medalla,
/// corona para el nº 1, username y totales.
class _PodiumSpot extends StatelessWidget {
  final GlobalLeaderboardEntry entry;
  final Color medal;
  final double avatarSize;
  final bool crowned;
  final bool isMe;
  const _PodiumSpot({
    required this.entry,
    required this.medal,
    required this.avatarSize,
    this.crowned = false,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crowned) ...[
          Icon(Icons.emoji_events, color: medal, size: 26),
          const SizedBox(height: 4),
        ],
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: medal, width: 2.5),
            gradient: RadialGradient(
              colors: [medal.withValues(alpha: 0.28), Colors.transparent],
            ),
            boxShadow: [
              BoxShadow(color: medal.withValues(alpha: 0.35), blurRadius: 16),
            ],
          ),
          child: Text(
            _initial(entry.username),
            style: TextStyle(
              color: onBackground,
              fontSize: avatarSize * 0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '#${entry.rank}',
          style: TextStyle(
            color: medal,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isMe ? '${entry.username} · ${l10n.globalLeaderboardYou}' : entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onBackground,
            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.totalScore} ${l10n.globalLeaderboardPointsSuffix}',
          style: TextStyle(
            color: onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        _TotalStarsChip(count: entry.totalStars, muted: muted),
      ],
    );
  }

  static String _initial(String username) =>
      username.isEmpty ? '?' : username.characters.first.toUpperCase();
}

/// Fila glass del ranking (del 4º en adelante). La propia se resalta con el
/// acento primario y la etiqueta "Tú".
class _RankingTile extends StatelessWidget {
  final GlobalLeaderboardEntry entry;
  final bool isMe;
  const _RankingTile({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? primary.withValues(alpha: 0.14) : glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? primary.withValues(alpha: 0.55) : glassBorder,
          width: isMe ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(color: muted, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.username,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onBackground,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  _YouBadge(label: l10n.globalLeaderboardYou),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TotalStarsChip(count: entry.totalStars, muted: muted),
          const SizedBox(width: 14),
          Text(
            '${entry.totalScore}',
            style: TextStyle(
              color: onBackground,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Total de estrellas acumuladas (suma de las mejores por nivel): número +
/// estrella dorada, compacto — aquí no aplican las 3 estrellas por nivel.
class _TotalStarsChip extends StatelessWidget {
  final int count;
  final Color muted;
  const _TotalStarsChip({required this.count, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: AppColors.victory),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _YouBadge extends StatelessWidget {
  final String label;
  const _YouBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? AppColors.onBackground : primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Barra propia anclada bajo la lista cuando el jugador clasifica fuera del
/// top: siempre sabes dónde estás y a cuánto queda el de arriba (Q8/ADR 0006).
class _AnchoredMeBar extends StatelessWidget {
  final GlobalLeaderboardEntry me;
  const _AnchoredMeBar({required this.me});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      // Sin borde propio: el _RankingTile interior ya dibuja el acento primario;
      // aquí solo se aporta el fondo sólido y la elevación de "docked bar".
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.30 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _RankingTile(entry: me, isMe: true),
    );
  }
}

/// Pie "sin clasificar": sesión sin ningún score de campaña enviado.
class _UnrankedFooter extends StatelessWidget {
  const _UnrankedFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 16, color: muted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.globalLeaderboardUnranked,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
            l10n.globalLeaderboardEmpty,
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
    final l10n = AppLocalizations.of(context);
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
            l10n.globalLeaderboardError,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

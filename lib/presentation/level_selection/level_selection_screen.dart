import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/level_catalog_provider.dart';
import '../../application/state/level_selection_state.dart';
import '../../core/router/app_router.dart';
import '../../core/router/route_observer.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/tier.dart';
import '../../l10n/app_localizations.dart';
import '../providers/level_selection_provider.dart';

/// Selección de nivel: agrupa el Catálogo remoto (front#8) por Tier (que es, a
/// la vez, la agrupación por dificultad), muestra las estrellas ganadas por
/// nivel y bloquea los niveles de Tiers aún no alcanzados. Cada celda muestra
/// su POSICIÓN en el Catálogo pero navega con el LevelId REAL del back,
/// alineando juego y leaderboard con los ids oficiales. La lista y el estado de
/// bloqueo los resuelve `levelSelectionControllerProvider`; esta pantalla es
/// pura presentación. loading → spinner; error → mensaje + reintentar (refresh
/// del Catálogo).
class LevelSelectionScreen extends ConsumerStatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  ConsumerState<LevelSelectionScreen> createState() =>
      _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends ConsumerState<LevelSelectionScreen>
    with RouteAware {
  // Recompone catálogo + progreso: refleja las estrellas y los Tiers recién
  // desbloqueados al (re)entrar al selector. El provider no es autoDispose, así
  // que sin esto su `build()` correría una sola vez por sesión y quedaría
  // desactualizado tras ganar una partida. El Catálogo remoto ya resuelto se
  // reutiliza (levelCatalogProvider no se invalida aquí): solo se relee el
  // progreso local.
  void _refresh() {
    if (mounted) ref.invalidate(levelSelectionControllerProvider);
  }

  // Retry del estado de error: refresca el Catálogo remoto (si fue él quien
  // falló, p. ej. sin red y sin caché) y recompone el selector.
  void _retry() {
    ref.read(levelCatalogProvider.notifier).refresh();
    _refresh();
  }

  @override
  void initState() {
    super.initState();
    // Entrada por montaje: Home→Play, o "Back to Levels" (que recrea la
    // pantalla con `pushNamedAndRemoveUntil`).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se suscribe al observador para enterarse de los `pop` de rutas encima.
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // La pantalla se revela al hacer `pop` de la de encima (p. ej. volver de una
    // partida sin recrear el selector: "Next Level" y luego back del
    // dispositivo). Recomponer para reflejar el progreso nuevo.
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final sections = ref.watch(levelSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLevel),
        backgroundColor: surface,
      ),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CatalogError(
          message: l10n.levelsLoadError,
          retryLabel: l10n.retry,
          onRetry: _retry,
        ),
        data: (view) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final section in view.campaignTiers)
              _TierSectionView(section: section),
            // Bloque temático: solo si el back publicó niveles temáticos. Si no
            // hay, no se renderiza nada extra (los catálogos solo-campaña se ven
            // idénticos a antes).
            if (view.themedTiles.isNotEmpty)
              _ThemedSectionView(tiles: view.themedTiles),
          ],
        ),
      ),
    );
  }
}

/// Estado de error del Catálogo: mensaje + botón de reintentar.
class _CatalogError extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _CatalogError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// Encabezado de dificultad + cuadrícula de niveles de un Tier.
class _TierSectionView extends StatelessWidget {
  final TierSection section;
  const _TierSectionView({required this.section});

  // Mapea los 5 Tiers de la rampa a las 3 etiquetas de dificultad del enunciado.
  static String _difficultyLabel(AppLocalizations l10n, Tier tier) =>
      switch (tier) {
        Tier.one || Tier.two => l10n.difficultyEasy,
        Tier.three => l10n.difficultyMedium,
        Tier.four || Tier.five => l10n.difficultyHard,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Text(
                l10n.tierLabel(section.tier.rank),
                style: TextStyle(
                  color: onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${_difficultyLabel(l10n, section.tier)}',
                style: TextStyle(color: muted, fontSize: 14),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final tile in section.tiles) _LevelTileView(tile: tile),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Encabezado "Themed" + cuadrícula de niveles temáticos. Reutiliza
/// `_LevelTileView`: como los tiles temáticos llegan con `locked == false`, se
/// pintan siempre tappables y sin candado, y navegan con el LevelId REAL igual
/// que la campaña. Sin gating ni etiqueta de dificultad (no pertenecen a un Tier).
class _ThemedSectionView extends StatelessWidget {
  final List<LevelTile> tiles;
  const _ThemedSectionView({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            l10n.themedSection,
            style: TextStyle(
              color: onBackground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final tile in tiles) _LevelTileView(tile: tile),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Celda de un nivel: posición en el Catálogo + fila de estrellas si está
/// desbloqueado; candado si está bloqueado. Los desbloqueados navegan a la
/// partida (tap) con el LevelId REAL y ofrecen el acceso al ranking del nivel
/// (front#17). Los bloqueados no hacen nada.
class _LevelTileView extends StatelessWidget {
  final LevelTile tile;
  const _LevelTileView({required this.tile});

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

    final panel = Container(
      key: ValueKey('level-tile-${tile.levelId.value}'),
      decoration: BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder),
      ),
      alignment: Alignment.center,
      child: tile.locked
          ? Icon(Icons.lock, color: muted, size: 26)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // La celda muestra la POSICIÓN (orden de juego); el id real
                  // del back es opaco y solo viaja en la navegación.
                  '${tile.position}',
                  style: TextStyle(
                    color: onBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _StarRow(stars: tile.stars),
              ],
            ),
    );

    if (tile.locked) return panel; // bloqueado: no navega, sin ripple.

    // Desbloqueado: el tap juega el nivel; el icono de ranking (front#17)
    // superpuesto arriba a la derecha lleva a su leaderboard sin robar el tap.
    return Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.game,
              arguments: tile.levelId,
            ),
            borderRadius: BorderRadius.circular(12),
            child: panel,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.leaderboard, size: 18),
            tooltip: AppLocalizations.of(context).viewLeaderboard,
            color: onBackground,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRouter.leaderboard,
              arguments: tile.levelId,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tres ranuras de estrella; se llenan hasta [stars] (0..3).
class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  static const int _maxStars = 3;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.onSurfaceMuted
        : AppColors.lightOnSurfaceMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _maxStars; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: 14,
            color: i < stars ? AppColors.victory : muted,
          ),
      ],
    );
  }
}

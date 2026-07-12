import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/level_catalog_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Cuadrícula de selección de nivel alimentada por el Catálogo remoto
/// (levelCatalogProvider). Cada celda muestra su POSICIÓN en el Catálogo
/// (`i + 1`) pero navega con el LevelId REAL del back, alineando juego y
/// leaderboard con los ids oficiales. loading → spinner; error → mensaje +
/// reintentar (refresh del Catálogo).
class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final catalog = ref.watch(levelCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLevel),
        backgroundColor: surface,
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CatalogError(
          message: l10n.catalogError,
          retryLabel: l10n.retry,
          onRetry: () => ref.read(levelCatalogProvider.notifier).refresh(),
        ),
        data: (ids) => _LevelGrid(ids: ids),
      ),
    );
  }
}

/// Cuadrícula de niveles: `ids.length` celdas, cada una etiquetada por su
/// posición (i+1) y con navegación al LevelId real correspondiente.
class _LevelGrid extends StatelessWidget {
  final List<LevelId> ids;
  const _LevelGrid({required this.ids});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: ids.length,
      itemBuilder: (context, i) => InkWell(
        // La celda muestra la posición (i+1) pero navega con el LevelId real.
        onTap: () =>
            Navigator.pushNamed(context, AppRouter.game, arguments: ids[i]),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glassBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '${i + 1}',
            style: TextStyle(
              color: onBackground,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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

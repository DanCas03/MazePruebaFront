import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/level_progress_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/board/entities/level_progress_entry.dart';
import '../../../domain/game_core/value_objects/level_id.dart';
import '../../game/screens/game_screen.dart';

/// Cantidad de niveles ofrecidos en la selección. Como la generación es
/// procedural, cada número produce un tablero determinista distinto.
const int kTotalLevels = 12;

/// Pantalla de selección de niveles. `watch`ea el progreso persistido para
/// marcar niveles completados y mostrar la mejor marca.
class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(levelProgressListProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Niveles'),
        foregroundColor: AppColors.onSurface,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [AppColors.background, AppColors.backgroundDeep],
          ),
        ),
        child: SafeArea(
          child: progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error al cargar progreso: $e')),
            data: (progress) => _LevelGrid(progress: progress),
          ),
        ),
      ),
    );
  }
}

class _LevelGrid extends StatelessWidget {
  final List<LevelProgressEntry> progress;

  const _LevelGrid({required this.progress});

  LevelProgressEntry? _entryFor(int level) {
    for (final e in progress) {
      if (e.levelId.value == level) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.92,
      ),
      itemCount: kTotalLevels,
      itemBuilder: (context, index) {
        final level = index + 1;
        final entry = _entryFor(level);
        final completed = entry?.isCompleted ?? false;
        final accent = AppColors.arrowColor(index);

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameScreen(levelId: LevelId(level)),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: completed ? accent : AppColors.pill,
                width: completed ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$level',
                  style: TextStyle(
                    color: completed ? accent : AppColors.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                if (completed)
                  Text(
                    '★ ${entry!.bestMoveCount.value}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Icon(Icons.play_arrow,
                      color: AppColors.muted, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

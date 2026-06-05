// lib/application/providers/level_progress_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/entities/level_progress_entry.dart';
import 'dependency_providers.dart';

/// Provee el progreso de todos los niveles ya jugados.
///
/// La pantalla de selección lo `watch`ea para marcar niveles completados. Tras
/// ganar una partida se invalida (`ref.invalidate`) para forzar la relectura
/// desde el repositorio de persistencia.
final levelProgressListProvider =
    FutureProvider<List<LevelProgressEntry>>((ref) async {
  final repo = ref.watch(levelProgressRepositoryProvider);
  return repo.loadAllProgress();
});

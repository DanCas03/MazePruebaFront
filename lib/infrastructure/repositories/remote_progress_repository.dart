import '../../domain/board/repositories/i_remote_progress_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/board/value_objects/level_progress.dart';
import '../data_sources/remote/remote_progress_data_source.dart';

/// Adapter: implementa el puerto remoto mapeando `LevelProgress` <-> el shape
/// JSON de `/progress` (back#8). Los null de score/estrellas se omiten en el
/// push (campos opcionales del back) y se leen como null en el pull.
class RemoteProgressRepository implements IRemoteProgressRepository {
  final RemoteProgressDataSource _dataSource;
  RemoteProgressRepository(this._dataSource);

  @override
  Future<List<LevelProgress>> pull() async {
    final rows = await _dataSource.getProgress();
    return rows.map(_fromJson).toList();
  }

  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async {
    final rows = await _dataSource.postProgress(progress.map(_toJson).toList());
    return rows.map(_fromJson).toList();
  }

  LevelProgress _fromJson(dynamic row) {
    final m = row as Map;
    return LevelProgress(
      levelId: LevelId(m['levelId'] as String),
      completed: m['completed'] as bool,
      bestScore: m['bestScore'] as int?,
      bestStars: m['bestStars'] as int?,
    );
  }

  Map<String, dynamic> _toJson(LevelProgress p) => {
        'levelId': p.levelId.value,
        'completed': p.completed,
        if (p.bestScore != null) 'bestScore': p.bestScore,
        if (p.bestStars != null) 'bestStars': p.bestStars,
      };
}

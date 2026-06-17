import 'package:equatable/equatable.dart';
import '../../core/exceptions/invalid_level_id_exception.dart';

class LevelId extends Equatable {
  final String value;
  LevelId(this.value) {
    if (value.trim().isEmpty) throw InvalidLevelIdException('LevelId cannot be blank');
  }

  @override
  List<Object?> get props => [value];
}

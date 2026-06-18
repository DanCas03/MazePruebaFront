import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/local/hive_level_progress_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/hive_progress_repository.dart';
import 'package:flutter_arrow_maze/presentation/providers/dependency_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    // Arrange — un contenedor Riverpod aislado por test.
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('dependency_providers (composition root)', () {
    test('loggerServiceProvider resuelve un LoggerServiceAdapter', () {
      // Act
      final logger = container.read(loggerServiceProvider);

      // Assert
      expect(logger, isA<ILoggerService>());
      expect(logger, isA<LoggerServiceAdapter>());
    });

    test('hiveDataSourceProvider resuelve un HiveLocalDataSource', () {
      // Act
      final dataSource = container.read(hiveDataSourceProvider);

      // Assert
      expect(dataSource, isA<HiveLocalDataSource>());
    });

    test('levelProgressRepositoryProvider resuelve un HiveProgressRepository', () {
      // Act
      final repository = container.read(levelProgressRepositoryProvider);

      // Assert
      expect(repository, isA<ILevelProgressRepository>());
      expect(repository, isA<HiveProgressRepository>());
    });

    test('levelGeneratorProvider resuelve un GraphBoardGenerator', () {
      // Act
      final generator = container.read(levelGeneratorProvider);

      // Assert
      expect(generator, isA<ILevelGenerator>());
      expect(generator, isA<GraphBoardGenerator>());
    });

    test('los providers son singletons dentro de un mismo contenedor', () {
      // Act
      final logger1 = container.read(loggerServiceProvider);
      final logger2 = container.read(loggerServiceProvider);
      final repo1 = container.read(levelProgressRepositoryProvider);
      final repo2 = container.read(levelProgressRepositoryProvider);

      // Assert
      expect(identical(logger1, logger2), isTrue);
      expect(identical(repo1, repo2), isTrue);
    });
  });
}

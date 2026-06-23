import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'logger_service_adapter_test.mocks.dart';

@GenerateMocks([Logger])
void main() {
  late MockLogger mockLogger;
  late LoggerServiceAdapter adapter;

  setUp(() {
    mockLogger = MockLogger();
    adapter = LoggerServiceAdapter(logger: mockLogger);
  });

  test('implements the ILoggerService port', () {
    // Arrange + Act + Assert
    expect(adapter, isA<ILoggerService>());
  });

  test('log delegates to logger.i with [context] message format', () {
    // Arrange
    const message = 'level loaded';
    const context = 'GameController';

    // Act
    adapter.log(message, context);

    // Assert
    verify(mockLogger.i('[GameController] level loaded')).called(1);
  });

  test('error delegates to logger.e with formatted message and error object',
      () {
    // Arrange
    const message = 'failed to save';
    const context = 'HiveRepository';
    final cause = Exception('disk full');

    // Act
    adapter.error(message, context, cause);

    // Assert
    verify(mockLogger.e('[HiveRepository] failed to save', error: cause))
        .called(1);
  });

  test('error forwards null error object when none is provided', () {
    // Arrange
    const message = 'unexpected state';
    const context = 'Notifier';

    // Act
    adapter.error(message, context);

    // Assert
    verify(mockLogger.e('[Notifier] unexpected state', error: null)).called(1);
  });

  test('warn delegates to logger.w with [context] message format', () {
    // Arrange
    const message = 'cache miss';
    const context = 'BoardGenerator';

    // Act
    adapter.warn(message, context);

    // Assert
    verify(mockLogger.w('[BoardGenerator] cache miss')).called(1);
  });
}

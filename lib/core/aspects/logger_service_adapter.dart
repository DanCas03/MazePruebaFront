import 'package:logger/logger.dart';

import 'i_logger_service.dart';

// Adapter (GoF): adapta el package externo `logger` al puerto
// ILoggerService, aislando el resto de la app del API concreto del package.
class LoggerServiceAdapter implements ILoggerService {
  LoggerServiceAdapter({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  @override
  void log(String message, String context) => _logger.i('[$context] $message');

  @override
  void error(String message, String context, [Object? error]) =>
      _logger.e('[$context] $message', error: error);

  @override
  void warn(String message, String context) => _logger.w('[$context] $message');
}

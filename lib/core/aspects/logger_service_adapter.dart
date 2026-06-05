// lib/core/aspects/logger_service_adapter.dart

import 'package:logger/logger.dart';

import 'i_logger_service.dart';

/// Adaptador que implementa [ILoggerService] envolviendo el paquete `logger`.
///
/// Patrón Adapter: el `Logger` de la librería (adaptee) se adapta al contrato
/// interno [ILoggerService] (target). Es el ÚNICO archivo del proyecto que
/// importa `package:logger/logger.dart`; si mañana cambiamos de librería, solo
/// se reescribe esta clase.
class LoggerServiceAdapter implements ILoggerService {
  final Logger _logger;

  LoggerServiceAdapter([Logger? logger])
      : _logger = logger ?? Logger(printer: SimplePrinter());

  @override
  void log(String message, {String? tag}) {
    _logger.i(_format(message, tag));
  }

  @override
  void warn(String message, {String? tag}) {
    _logger.w(_format(message, tag));
  }

  @override
  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _logger.e(_format(message, tag), error: error, stackTrace: stackTrace);
  }

  String _format(String message, String? tag) =>
      tag == null ? message : '[$tag] $message';
}

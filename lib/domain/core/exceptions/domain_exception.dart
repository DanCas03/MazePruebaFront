// lib/domain/core/exceptions/domain_exception.dart

/// Excepción base de la capa de Dominio.
///
/// DDD: las reglas de negocio fallan con errores semánticos propios del
/// dominio, nunca con errores genéricos de framework. Toda excepción del
/// dominio hereda de esta clase para poder capturarlas de forma uniforme en
/// las capas externas (p. ej. un manejador AOP de errores).
abstract class DomainException implements Exception {
  final String message;

  const DomainException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

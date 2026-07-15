import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/arrows/entities/arrow.dart';
import 'arrow_color.dart';

/// Provider del seam de color (front#67). Presentación-local: el resolver
/// devuelve `Color` (tipo de presentación), por eso vive aquí y no en `core/di`
/// (que no debe importar presentación). El default es el adapter temático, que
/// cae a identidad cuando no hay Instrucciones de pintado → campaña intacta.
/// Sobreescribible en tests para forzar un adapter concreto.
final arrowColorResolverProvider = Provider<ArrowColorResolver>(
  (_) => const ThemedArrowColorResolver(),
);

/// Seam de color de flechas (front#67, ADR 0004). El color deja de ser una
/// llamada directa a `arrowColorFor` y pasa a ser una decisión inyectable con
/// dos adapters intercambiables (OCP): identidad (campaña) y temático
/// (Instrucciones de pintado). Los painters siguen recibiendo `Color` como
/// primitiva — no conocen al resolver.
abstract class ArrowColorResolver {
  /// Color de [arrow]. [palette] son las Instrucciones de pintado del nivel
  /// (rol→hex); nula/ausente = campaña.
  Color colorFor(Arrow arrow, Map<String, String>? palette);
}

/// Adapter por defecto: color ESTABLE por identidad (la paleta hash actual de
/// `arrow_color.dart`). Ignora la paleta. Envuelve la lógica existente sin
/// cambiarla, así la campaña se pinta byte-idéntica a antes del seam.
class IdentityArrowColorResolver implements ArrowColorResolver {
  const IdentityArrowColorResolver();

  @override
  Color colorFor(Arrow arrow, Map<String, String>? palette) =>
      arrowColorFor(arrow.id);
}

/// Adapter temático: resuelve `Arrow.paintRole` contra la `palette` (hex servido
/// verbatim, misma figura en claro y oscuro — fidelidad > adaptación). Cae al
/// [_fallback] (identidad) cuando la flecha no tiene rol, el rol no está en la
/// paleta, o el hex es inválido: así una figura incompleta nunca rompe el
/// render y la campaña (sin roles) reproduce exactamente la paleta por identidad.
class ThemedArrowColorResolver implements ArrowColorResolver {
  final ArrowColorResolver _fallback;

  const ThemedArrowColorResolver(
      [this._fallback = const IdentityArrowColorResolver()]);

  @override
  Color colorFor(Arrow arrow, Map<String, String>? palette) {
    final role = arrow.paintRole;
    if (role == null || palette == null) {
      return _fallback.colorFor(arrow, palette);
    }
    final hex = palette[role];
    if (hex == null) return _fallback.colorFor(arrow, palette);
    return parseHexColor(hex) ?? _fallback.colorFor(arrow, palette);
  }

  /// Parsea `#RRGGBB` (o `#AARRGGBB`) a [Color] opaco. Devuelve null ante forma
  /// inválida — el llamador decide el fallback. Estático y puro para testearlo.
  static Color? parseHexColor(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h'; // sin alfa → opaco
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }
}

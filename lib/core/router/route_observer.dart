import 'package:flutter/widgets.dart';

/// Observador de rutas de la app, registrado en `MaterialApp.navigatorObservers`.
///
/// Permite que una pantalla (mediante `RouteAware`) reaccione cuando se la
/// **revela** al hacer `pop` de la ruta que tenía encima — no solo cuando se
/// (re)crea. Lo usa el selector de nivel para recomponer su progreso al volver
/// de una partida aunque su instancia haya seguido montada al fondo de la pila
/// (p. ej. "Next Level" y luego back del dispositivo).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

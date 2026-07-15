import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Cámara de zoom/pan que envuelve el tablero (front#66). Da a CUALQUIER tablero
/// —campaña o generado— pellizco para acercar, arrastre para desplazar y un
/// doble toque para alternar entre "fit" (tablero completo) y un zoom de lectura
/// centrado en la zona tocada. Sin esta cámara, un 50×50 encoge las celdas hasta
/// hacerlas injugables en móvil (el problema que abre #66).
///
/// CULLING: expone al [builder] el rectángulo VISIBLE del tablero (en coordenadas
/// locales del tablero, origen en su esquina superior izquierda) recalculado en
/// cada cambio de la cámara. El tablero lo usa para construir SOLO las flechas y
/// pintar SOLO las líneas de rejilla dentro del encuadre — clave para mantener
/// los FPS al hacer pan sobre un XL de 2 500 celdas, donde construir las ~200
/// [ArrowWidget] (cada una con su AnimationController) fuera de cámara es puro
/// desperdicio.
///
/// El hit-testing por celda del tablero sigue siendo válido a cualquier escala:
/// [InteractiveViewer] transforma los eventos de puntero al espacio local del
/// hijo (`transformHitTests`), así que el `onTapUp` interior recibe coordenadas
/// locales del tablero sin importar el zoom/pan (criterio de aceptación #66).
class BoardViewport extends StatefulWidget {
  /// Tamaño del área disponible (el viewport de la cámara).
  final Size viewportSize;

  /// Tamaño natural del tablero YA ajustado a "fit" por quien construye.
  final Size boardSize;

  /// Construye el contenido del tablero dado el rectángulo visible (coords
  /// locales del tablero), o `null` si aún no se puede calcular (se dibuja todo).
  final Widget Function(Rect? visibleRect) builder;

  const BoardViewport({
    super.key,
    required this.viewportSize,
    required this.boardSize,
    required this.builder,
  });

  @override
  State<BoardViewport> createState() => _BoardViewportState();
}

class _BoardViewportState extends State<BoardViewport>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();

  // Animación de la transición de doble-tap (fit ↔ zoom de lectura). Se crea en
  // initState (no como `late final` con inicializador): crear un
  // AnimationController hace un lookup de TickerMode en el árbol, y si el
  // inicializador perezoso se disparara dentro de dispose() (cuando nunca hubo
  // doble-tap) el elemento ya estaría desactivado → crash.
  late final AnimationController _anim;
  Animation<Matrix4>? _zoomAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_applyAnimatedMatrix);
  }

  // Detección de doble-tap SIN GestureRecognizer: un `DoubleTapGestureRecognizer`
  // retiene la arena de gestos ~300 ms y añadiría esa latencia a CADA toque de
  // flecha (la interacción central del juego). En su lugar detectamos el doble
  // toque con un `Listener` de puntero crudo, que no compite en la arena: los
  // toques de flecha del `GestureDetector` interior siguen disparando al instante.
  Duration? _lastTapTime;
  Offset? _lastTapPos;

  // Escala del zoom de lectura y umbral para considerar "en fit" (minScale=1.0).
  static const double _readScale = 2.6;
  static const double _minScale = 1.0;
  static const double _maxScale = 8.0;
  static const double _fitEpsilon = 1.05;

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Offset del tablero dentro del viewport cuando se centra en "fit" (letterbox).
  Offset get _centerOffset => Offset(
        ((widget.viewportSize.width - widget.boardSize.width) / 2)
            .clamp(0.0, double.infinity),
        ((widget.viewportSize.height - widget.boardSize.height) / 2)
            .clamp(0.0, double.infinity),
      );

  /// Rectángulo visible en coordenadas LOCALES del tablero. Invierte la matriz
  /// de la cámara sobre las esquinas del viewport y descuenta el centrado.
  Rect? _visibleBoardRect() {
    final inverse = Matrix4.tryInvert(_controller.value);
    if (inverse == null) return null;
    final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(
      inverse,
      Offset(widget.viewportSize.width, widget.viewportSize.height),
    );
    final offset = _centerOffset;
    return Rect.fromPoints(topLeft, bottomRight)
        .translate(-offset.dx, -offset.dy);
  }

  void _applyAnimatedMatrix() {
    final anim = _zoomAnim;
    if (anim != null) _controller.value = anim.value;
  }

  void _animateTo(Matrix4 target) {
    _zoomAnim = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim
      ..reset()
      ..forward();
  }

  void _handlePointerUp(PointerUpEvent event) {
    final now = event.timeStamp;
    final pos = event.localPosition;
    final last = _lastTapTime;
    final lastPos = _lastTapPos;
    final isDoubleTap = last != null &&
        lastPos != null &&
        now - last <= kDoubleTapTimeout &&
        (pos - lastPos).distance <= kDoubleTapSlop;
    if (isDoubleTap) {
      _lastTapTime = null;
      _lastTapPos = null;
      _toggleZoom(pos);
    } else {
      _lastTapTime = now;
      _lastTapPos = pos;
    }
  }

  /// Doble toque: si ya estamos acercados, vuelve a "fit"; si no, acerca a
  /// [_readScale] manteniendo bajo el dedo el punto [viewportPoint] tocado.
  void _toggleZoom(Offset viewportPoint) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final Matrix4 target;
    if (currentScale > _fitEpsilon) {
      target = Matrix4.identity();
    } else {
      final inverse = Matrix4.tryInvert(_controller.value) ?? Matrix4.identity();
      final childPoint = MatrixUtils.transformPoint(inverse, viewportPoint);
      // T·p = s·p + t con t = viewportPoint − s·childPoint deja el punto tocado
      // fijo bajo el dedo. Se compone la matriz a mano para no usar los
      // Matrix4.translate/scale (deprecados en el vector_math actual).
      const s = _readScale;
      target = Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(0, 3, viewportPoint.dx - s * childPoint.dx)
        ..setEntry(1, 3, viewportPoint.dy - s * childPoint.dy);
    }
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: _handlePointerUp,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: _minScale,
        maxScale: _maxScale,
        // clipBehavior por defecto recorta lo que sale del viewport al hacer pan.
        child: SizedBox(
          width: widget.viewportSize.width,
          height: widget.viewportSize.height,
          child: Center(
            child: SizedBox(
              width: widget.boardSize.width,
              height: widget.boardSize.height,
              // Recalcula el encuadre (y por tanto el culling) en cada cambio de
              // la cámara. El AnimatedBuilder observa el TransformationController.
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => widget.builder(_visibleBoardRect()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

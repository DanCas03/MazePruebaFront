import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/presentation/game/widgets/exiting_arrow_widget.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/snake_exit_painter.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Flecha DOBLADA: cola (0,0) → curva (1,0) → cabeza (1,1).
/// headDirection = right (la cabeza sale hacia la derecha).
Arrow _bentArrow() => Arrow(
      id: const ArrowId('bent-0'),
      cells: [
        Position(row: 0, col: 0), // cola
        Position(row: 1, col: 0), // codo
        Position(row: 1, col: 1), // cabeza
      ],
      headDirection: Direction.right,
    );

/// Envuelve el widget en un árbol Flutter mínimo con tamaño fijo.
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 288, height: 288, child: child),
      ),
    );

/// Crea un [ExitingArrowWidget] con la flecha doblada de prueba.
ExitingArrowWidget _widget({int nonce = 1, Duration? duration}) =>
    ExitingArrowWidget(
      key: ValueKey('exiting-$nonce'),
      arrow: _bentArrow(),
      minCol: 0,
      minRow: 0,
      cols: 4,
      rows: 4,
      cell: 72,
      color: const Color(0xFF46B98C),
      nonce: nonce,
      duration: duration ?? const Duration(milliseconds: 360),
    );

// ── Helper: busca el CustomPaint cuyo painter es SnakeExitPainter ─────────────

/// Devuelve el primer [CustomPaint] cuyo `.painter` es [SnakeExitPainter],
/// o null si no existe ninguno.
SnakeExitPainter? _findSnakePainter(WidgetTester tester) {
  final matches = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((cp) => cp.painter is SnakeExitPainter)
      .toList();
  if (matches.isEmpty) return null;
  return matches.first.painter as SnakeExitPainter;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ExitingArrowWidget', () {
    // ── (a) Monta sin lanzar excepción y pinta un CustomPaint con SnakeExitPainter
    testWidgets(
      '(a) monta con flecha doblada sin lanzar y contiene SnakeExitPainter',
      (tester) async {
        // Arrange
        final widget = _widget(nonce: 1);

        // Act
        await tester.pumpWidget(_host(widget));

        // Assert — el widget aparece en el árbol
        expect(find.byType(ExitingArrowWidget), findsOneWidget);

        // Assert — hay al menos un CustomPaint cuyo painter es SnakeExitPainter
        final painter = _findSnakePainter(tester);
        expect(painter, isNotNull,
            reason: 'debe existir un CustomPaint con SnakeExitPainter');
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
      },
    );

    // ── (b) progress crece al avanzar la animación
    testWidgets(
      '(b) el SnakeExitPainter recibe progress creciente al avanzar la animación',
      (tester) async {
        // Arrange
        await tester.pumpWidget(_host(_widget(nonce: 2)));
        // Leer progress justo tras montar (t ≈ 0, antes del primer tick)
        final p0 = _findSnakePainter(tester)?.progress ?? 0.0;

        // Act — avanzar 120 ms (≈ 1/3 de los 360 ms totales)
        await tester.pump(const Duration(milliseconds: 120));

        // Assert — progress ha crecido
        final p1 = _findSnakePainter(tester)?.progress ?? 0.0;
        expect(p1, greaterThan(p0),
            reason: 'progress debe crecer al avanzar la animación');

        // Act — avanzar otro tercio
        await tester.pump(const Duration(milliseconds: 120));

        // Assert — sigue creciendo
        final p2 = _findSnakePainter(tester)?.progress ?? 0.0;
        expect(p2, greaterThan(p1),
            reason: 'progress debe seguir creciendo con cada tick');

        await tester.pumpAndSettle();
      },
    );

    // ── (c) Al completarse la animación el widget colapsa a SizedBox.shrink
    testWidgets(
      '(c) al completarse la animación (360 ms) el widget colapsa a SizedBox.shrink',
      (tester) async {
        // Arrange
        await tester.pumpWidget(_host(_widget(nonce: 3)));
        expect(_findSnakePainter(tester), isNotNull,
            reason: 'antes de completar debe haber SnakeExitPainter');

        // Act — avanzar más allá de la duración total (360 ms)
        await tester.pump(const Duration(milliseconds: 400));

        // Assert — ya no hay SnakeExitPainter (el builder devuelve SizedBox.shrink)
        final painterAfter = _findSnakePainter(tester);
        expect(painterAfter, isNull,
            reason:
                'tras completarse la animación no debe haber SnakeExitPainter');

        // Assert — no hay error
        expect(tester.takeException(), isNull);
      },
    );

    // ── (d) #102: una duración custom (auto-solver comprimido) se respeta ──────
    testWidgets(
      '(d) una duración custom más corta completa la animación antes de 360 ms (#102)',
      (tester) async {
        // Arrange — el auto-solver comprime la animación a 120 ms en tableros
        // grandes (AutoSolvePacing.exitDurationFor); simulado aquí a mano.
        await tester.pumpWidget(
          _host(_widget(nonce: 20, duration: const Duration(milliseconds: 120))),
        );
        expect(_findSnakePainter(tester), isNotNull);

        // Act — avanzar más allá de los 120 ms custom, pero MUY por debajo del
        // default de 360 ms.
        await tester.pump(const Duration(milliseconds: 150));

        // Assert — ya completó (colapsó), a diferencia del default de 360 ms.
        expect(_findSnakePainter(tester), isNull,
            reason: 'con duration:120ms debe completar bien antes de 360ms');
        expect(tester.takeException(), isNull);
      },
    );

    // ── Dispose a mitad de animación no filtra AnimationController ─────────────
    testWidgets(
      'dispose a mitad de animación no filtra AnimationController',
      (tester) async {
        // Arrange
        await tester.pumpWidget(_host(_widget(nonce: 4)));
        await tester.pump(const Duration(milliseconds: 150));

        // Act — desmontar el widget antes de que termine
        await tester.pumpWidget(_host(const SizedBox.shrink()));

        // Assert — ninguna excepción ni error de controlador filtrado
        expect(tester.takeException(), isNull);
      },
    );

    // ── Keying: dos instancias con distinto nonce son widgets distintos ─────────
    testWidgets(
      'key por nonce distingue dos instancias simultáneas',
      (tester) async {
        // Arrange
        final w1 = _widget(nonce: 10);
        final w2 = _widget(nonce: 11);

        // Act
        await tester.pumpWidget(_host(Stack(children: [w1, w2])));

        // Assert — ambas instancias están en el árbol
        expect(find.byType(ExitingArrowWidget), findsNWidgets(2));

        // Assert — cada una tiene su propio SnakeExitPainter
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((cp) => cp.painter is SnakeExitPainter)
            .toList();
        expect(painters.length, greaterThanOrEqualTo(2),
            reason: 'cada ExitingArrowWidget debe tener su propio SnakeExitPainter');

        await tester.pumpAndSettle();
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/themed_selection_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Widget> _pageFor(WidgetTester tester, String name) async {
  // Arrange: pump a host app whose Builder captures a real BuildContext, then
  // drive the generator and build the page widget from the route's builder.
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  final route = AppRouter.onGenerateRoute(RouteSettings(name: name))
      as MaterialPageRoute<dynamic>;
  // Act
  return route.builder(capturedContext);
}

void main() {
  testWidgets('home route builds HomeScreen', (tester) async {
    expect(await _pageFor(tester, AppRouter.home), isA<HomeScreen>());
  });

  testWidgets('levelSelection route builds LevelSelectionScreen',
      (tester) async {
    expect(await _pageFor(tester, AppRouter.levelSelection),
        isA<LevelSelectionScreen>());
  });

  testWidgets('themed route builds ThemedSelectionScreen', (tester) async {
    expect(await _pageFor(tester, AppRouter.themed),
        isA<ThemedSelectionScreen>());
  });

  testWidgets('game route builds GameScreen', (tester) async {
    expect(await _pageFor(tester, AppRouter.game), isA<GameScreen>());
  });

  testWidgets('victory route builds VictoryScreen', (tester) async {
    expect(await _pageFor(tester, AppRouter.victory), isA<VictoryScreen>());
  });

  testWidgets('unknown route falls back to HomeScreen', (tester) async {
    expect(await _pageFor(tester, '/does-not-exist'), isA<HomeScreen>());
  });

  test('route constants expose the expected named paths', () {
    // Assert
    expect(AppRouter.home, '/');
    expect(AppRouter.levelSelection, '/levels');
    expect(AppRouter.themed, '/themed');
    expect(AppRouter.game, '/game');
    expect(AppRouter.victory, '/victory');
  });

  // front#103: la política centralizada de "camino de vuelta". Ambos helpers
  // deben conservar la ruta raíz `home` ('/') bajo el destino, de modo que
  // ninguna pantalla terminal deje al jugador varado (sin retorno al menú).
  group('return-path helpers', () {
    testWidgets(
        'backToLevels lands on level selection keeping the home root beneath',
        (tester) async {
      // Arrange: reproduce la pila Home → Levels → Game.
      final navKey = GlobalKey<NavigatorState>();
      late BuildContext gameCtx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.levelSelection => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    Scaffold(appBar: AppBar(title: const Text('levels'))),
              ),
            AppRouter.game => MaterialPageRoute<void>(
                settings: settings,
                builder: (context) {
                  gameCtx = context;
                  return const Scaffold(body: Text('game'));
                },
              ),
            _ => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('home-root')),
              ),
          },
        ),
      );
      navKey.currentState!.pushNamed(AppRouter.levelSelection);
      await tester.pumpAndSettle();
      navKey.currentState!.pushNamed(AppRouter.game);
      await tester.pumpAndSettle();

      // Act
      AppRouter.backToLevels(gameCtx);
      await tester.pumpAndSettle();

      // Assert: en el selector, con Home debajo ⇒ la flecha de retorno persiste.
      expect(find.text('levels'), findsOneWidget);
      expect(navKey.currentState!.canPop(), isTrue);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('exitToHome pops back to the home root without rebuilding it',
        (tester) async {
      // Arrange: reproduce la pila del flujo generado apilada sobre la raíz.
      final navKey = GlobalKey<NavigatorState>();
      var homeMounts = 0;
      late BuildContext resultCtx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.generatedGame => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('gen-game')),
              ),
            AppRouter.generatedResult => MaterialPageRoute<void>(
                settings: settings,
                builder: (context) {
                  resultCtx = context;
                  return const Scaffold(body: Text('gen-result'));
                },
              ),
            // La raíz cuenta sus montajes: si `exitToHome` la conservara mal
            // (borrándola y re-creándola) se montaría dos veces.
            _ => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => _MountCounter(
                  onMount: () => homeMounts++,
                  child: const Text('home-root'),
                ),
              ),
          },
        ),
      );
      expect(homeMounts, 1);
      navKey.currentState!.pushNamed(AppRouter.generatedGame);
      await tester.pumpAndSettle();
      navKey.currentState!.pushReplacementNamed(AppRouter.generatedResult);
      await tester.pumpAndSettle();
      expect(find.text('gen-result'), findsOneWidget);

      // Act
      AppRouter.exitToHome(resultCtx);
      await tester.pumpAndSettle();

      // Assert: de vuelta en la MISMA raíz (montada una sola vez) y sin nada que
      // desapilar ⇒ el AuthGate de '/' se preserva (no se estranguló el logout).
      expect(find.text('home-root'), findsOneWidget);
      expect(navKey.currentState!.canPop(), isFalse);
      expect(homeMounts, 1);
    });
  });
}

/// Widget de prueba que invoca [onMount] una vez, en su `initState`. Distingue
/// entre PRESERVAR una ruta (un solo montaje) y BORRARLA + re-crearla (dos).
class _MountCounter extends StatefulWidget {
  final VoidCallback onMount;
  final Widget child;
  const _MountCounter({required this.onMount, required this.child});

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: widget.child));
}

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
}

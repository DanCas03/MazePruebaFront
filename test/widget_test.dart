import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/main.dart';

void main() {
  testWidgets('ArrowMazeApp renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ArrowMazeApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

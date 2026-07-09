// test/presentation/auth/widgets/auth_text_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/presentation/auth/widgets/auth_text_field.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows its label and forwards typed text to the controller',
      (tester) async {
    // Arrange
    final controller = TextEditingController();
    await tester.pumpWidget(host(
      AuthTextField(controller: controller, label: 'Email'),
    ));
    // Act
    await tester.enterText(find.byType(TextField), 'hi@x.com');
    // Assert
    expect(find.text('Email'), findsOneWidget);
    expect(controller.text, 'hi@x.com');
  });

  testWidgets('renders the provided errorText', (tester) async {
    // Arrange / Act
    await tester.pumpWidget(host(
      AuthTextField(
        controller: TextEditingController(),
        label: 'Contraseña',
        errorText: 'Mínimo 8 caracteres',
      ),
    ));
    // Assert
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('obscures text when obscureText is true', (tester) async {
    await tester.pumpWidget(host(
      AuthTextField(
        controller: TextEditingController(),
        label: 'Contraseña',
        obscureText: true,
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_state.dart';
import 'package:flutter_arrow_maze/presentation/auth/auth_strings.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/register_screen.dart';

class _StubFormController extends AuthFormController {
  final AuthFormState _fixed;
  _StubFormController(this._fixed);
  @override
  AuthFormState build() => _fixed;
}

Widget _host(AuthFormState state) => ProviderScope(
      overrides: [
        authFormControllerProvider
            .overrideWith(() => _StubFormController(state)),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    );

void main() {
  testWidgets('shows password-too-short and mismatch errors on bad input',
      (tester) async {
    // Arrange
    await tester.pumpWidget(_host(const FormIdle()));
    // Act — valid email, short password, non-matching confirm
    await tester.enterText(
        find.widgetWithText(TextField, AuthStrings.emailLabel), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextField, AuthStrings.passwordLabel), 'short');
    await tester.enterText(
        find.widgetWithText(TextField, AuthStrings.confirmPasswordLabel), 'other');
    await tester
        .tap(find.widgetWithText(FilledButton, AuthStrings.registerButton));
    await tester.pump();
    // Assert
    expect(find.text(AuthStrings.passwordTooShort), findsOneWidget);
    expect(find.text(AuthStrings.confirmMismatch), findsOneWidget);
  });

  testWidgets('disables submit while FormSubmitting', (tester) async {
    await tester.pumpWidget(_host(const FormSubmitting()));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}

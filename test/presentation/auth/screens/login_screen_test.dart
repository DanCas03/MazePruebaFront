import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_state.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/presentation/auth/auth_strings.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/login_screen.dart';

/// Notifier de prueba que mantiene un estado fijo, para renderizar la pantalla
/// en cada AuthFormState sin ejecutar la lógica real.
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
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  testWidgets('shows validation errors when submitting empty fields',
      (tester) async {
    // Arrange
    await tester.pumpWidget(_host(const FormIdle()));
    // Act — tap the login button with empty email/password
    await tester.tap(find.widgetWithText(FilledButton, AuthStrings.loginButton));
    await tester.pump();
    // Assert
    expect(find.text(AuthStrings.emailInvalid), findsOneWidget);
    expect(find.text(AuthStrings.passwordEmpty), findsOneWidget);
  });

  testWidgets('disables the submit button while FormSubmitting', (tester) async {
    // Arrange / Act
    await tester.pumpWidget(_host(const FormSubmitting()));
    // Assert — button present but disabled (onPressed == null)
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows the failure message on FormError', (tester) async {
    // Arrange / Act
    await tester.pumpWidget(_host(const FormError(InvalidCredentials())));
    // Assert
    expect(find.text(const InvalidCredentials().message), findsOneWidget);
  });
}

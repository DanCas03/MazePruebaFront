import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_state.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/register_screen.dart';

class _StubFormController extends AuthFormController {
  final AuthFormState _fixed;
  _StubFormController(this._fixed);
  @override
  AuthFormState build() => _fixed;
}

// Locale 'es' (front#4): los literales esperados son las cadenas ES del ARB.
Widget _host(AuthFormState state) => ProviderScope(
      overrides: [
        authFormControllerProvider
            .overrideWith(() => _StubFormController(state)),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ),
    );

void main() {
  testWidgets('shows password-too-short and mismatch errors on bad input',
      (tester) async {
    // Arrange
    await tester.pumpWidget(_host(const FormIdle()));
    // Act — valid email, short password, non-matching confirm
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'short');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar contraseña'), 'other');
    await tester
        .tap(find.widgetWithText(FilledButton, 'Registrarme'));
    await tester.pump();
    // Assert
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('disables submit while FormSubmitting', (tester) async {
    await tester.pumpWidget(_host(const FormSubmitting()));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}

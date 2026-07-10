import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/core/auth/auth_gate.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/login_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';

import 'auth_gate_test.mocks.dart';

@GenerateMocks([IAuthTokenStorage])
void main() {
  Widget host(MockIAuthTokenStorage storage) => ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => AuthController(storage, RestoreSessionUseCase(storage)),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      );

  testWidgets('shows LoginScreen when unauthenticated', (tester) async {
    // Arrange
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => null);
    // Act
    await tester.pumpWidget(host(storage));
    await tester.pumpAndSettle();
    // Assert
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('shows HomeScreen when a valid token is restored', (tester) async {
    // Arrange — long-lived token (exp in 2100)
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => AuthToken(
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSIsImV4cCI6NDEwMjQ0NDgwMH0.sig'));
    // Act
    await tester.pumpWidget(host(storage));
    // HomeScreen anima su logo en bucle infinito (repeat), así que
    // pumpAndSettle nunca se asentaría (ver home_screen_test.dart); bombeamos
    // con pumps acotados en su lugar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Assert
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

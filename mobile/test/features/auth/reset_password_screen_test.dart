import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:maiditquick_mobile/shared/utils/password_validator.dart';

class _FakeResetApi extends ApiClient {
  bool resetCalled = false;
  String? submittedToken;
  String? submittedPassword;

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    if (path == '/v1/admin/reset-password' || path == '/api/auth/reset-password') {
      resetCalled = true;
      submittedToken = body['token']?.toString();
      submittedPassword = body['newPassword']?.toString() ?? body['password']?.toString();
      return <String, dynamic>{'message': 'Password updated'};
    }
    return <String, dynamic>{};
  }
}

void main() {
  group('PasswordRequirementState unit tests', () {
    test('Empty password satisfies none', () {
      final state = PasswordRequirementState.evaluate('');
      expect(state.hasMinLength, isFalse);
      expect(state.hasUppercase, isFalse);
      expect(state.hasLowercase, isFalse);
      expect(state.hasDigit, isFalse);
      expect(state.hasSpecial, isFalse);
      expect(state.allSatisfied, isFalse);
    });

    test('Evaluates individual criteria correctly', () {
      expect(PasswordRequirementState.evaluate('abcdefgh').hasMinLength, isTrue);
      expect(PasswordRequirementState.evaluate('abcdefgh').hasUppercase, isFalse);
      expect(PasswordRequirementState.evaluate('ABCDEFGH').hasLowercase, isFalse);
      expect(PasswordRequirementState.evaluate('abcdefgh').hasDigit, isFalse);
      expect(PasswordRequirementState.evaluate('abcdefgh').hasSpecial, isFalse);

      expect(PasswordRequirementState.evaluate('A').hasUppercase, isTrue);
      expect(PasswordRequirementState.evaluate('a').hasLowercase, isTrue);
      expect(PasswordRequirementState.evaluate('1').hasDigit, isTrue);

      for (final ch in ['!', '@', '#', '\$', '%', '^', '&', '*']) {
        expect(PasswordRequirementState.evaluate(ch).hasSpecial, isTrue,
            reason: 'Failed for special char $ch');
      }
    });

    test('Valid password satisfies all 5 criteria', () {
      final state = PasswordRequirementState.evaluate('Password123!');
      expect(state.hasMinLength, isTrue);
      expect(state.hasUppercase, isTrue);
      expect(state.hasLowercase, isTrue);
      expect(state.hasDigit, isTrue);
      expect(state.hasSpecial, isTrue);
      expect(state.allSatisfied, isTrue);
    });
  });

  group('ResetPasswordScreen Widget tests', () {
    late _FakeResetApi api;

    setUp(() {
      api = _FakeResetApi();
    });

    Widget buildTestScreen({String token = 'test-token-12345'}) {
      return MaterialApp(
        home: ResetPasswordScreen(
          api: api,
          initialToken: token,
        ),
      );
    }

    testWidgets('Initial state shows all requirements unsatisfied and button disabled',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.byKey(const Key('new_password_field')), findsOneWidget);
      expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('password_requirements_box')), findsOneWidget);

      // Verify all 5 requirement rows show ✗
      expect(find.text('✗ Minimum 8 characters'), findsOneWidget);
      expect(find.text('✗ At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('✗ At least 1 lowercase letter (a-z)'), findsOneWidget);
      expect(find.text('✗ At least 1 number (0-9)'), findsOneWidget);
      expect(find.text('✗ At least 1 special character (!@#\$%^&*)'), findsOneWidget);

      // Verify Reset Password button is disabled
      final buttonFinder = find.byKey(const Key('reset_password_button'));
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('Live updates requirement checklist as user types',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final newPasswordField = find.byKey(const Key('new_password_field'));

      // Type lowercase 'p'
      await tester.enterText(newPasswordField, 'p');
      await tester.pump();

      expect(find.text('✓ At least 1 lowercase letter (a-z)'), findsOneWidget);
      expect(find.text('✗ Minimum 8 characters'), findsOneWidget);
      expect(find.text('✗ At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('✗ At least 1 number (0-9)'), findsOneWidget);
      expect(find.text('✗ At least 1 special character (!@#\$%^&*)'), findsOneWidget);

      // Type uppercase 'P'
      await tester.enterText(newPasswordField, 'P');
      await tester.pump();

      expect(find.text('✓ At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('✗ At least 1 lowercase letter (a-z)'), findsOneWidget);

      // Type digit '1'
      await tester.enterText(newPasswordField, 'P1');
      await tester.pump();

      expect(find.text('✓ At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('✓ At least 1 number (0-9)'), findsOneWidget);

      // Type special character '!'
      await tester.enterText(newPasswordField, 'P1!');
      await tester.pump();

      expect(find.text('✓ At least 1 special character (!@#\$%^&*)'), findsOneWidget);
      expect(find.text('✗ Minimum 8 characters'), findsOneWidget);

      // Complete valid password: Password123!
      await tester.enterText(newPasswordField, 'Password123!');
      await tester.pump();

      expect(find.text('✓ Minimum 8 characters'), findsOneWidget);
      expect(find.text('✓ At least 1 uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('✓ At least 1 lowercase letter (a-z)'), findsOneWidget);
      expect(find.text('✓ At least 1 number (0-9)'), findsOneWidget);
      expect(find.text('✓ At least 1 special character (!@#\$%^&*)'), findsOneWidget);

      // Button is still disabled because confirm password is empty
      final ElevatedButton button =
          tester.widget(find.byKey(const Key('reset_password_button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('Button enables only when requirements met AND confirm matches',
        (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final newPasswordField = find.byKey(const Key('new_password_field'));
      final confirmPasswordField = find.byKey(const Key('confirm_password_field'));
      final buttonFinder = find.byKey(const Key('reset_password_button'));

      await tester.enterText(newPasswordField, 'Password123!');
      await tester.pump();

      // Enter mismatched password
      await tester.enterText(confirmPasswordField, 'Mismatch123!');
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Enter matching password
      await tester.enterText(confirmPasswordField, 'Password123!');
      await tester.pump();

      expect(find.text('Passwords do not match'), findsNothing);
      button = tester.widget(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Tap submit
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(api.resetCalled, isTrue);
      expect(api.submittedPassword, 'Password123!');
      expect(find.text('Password Changed'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
    });
  });
}

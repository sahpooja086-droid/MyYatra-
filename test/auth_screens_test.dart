import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/main.dart';
import 'package:myyatra/screens/auth/forgot_password_screen.dart';
import 'package:myyatra/screens/auth/login_screen.dart';

void main() {
  test('cloud opt-in requires Android debug and rejects emulator flags', () {
    expect(cloudDebugConfigurationError(isAndroidDebug: true), isNull);
    expect(
      cloudDebugConfigurationError(isAndroidDebug: false),
      contains('only in Android debug'),
    );
    expect(
      cloudDebugConfigurationError(
        isAndroidDebug: true,
        districtEmulator: true,
      ),
      contains('cannot be combined'),
    );
    expect(
      cloudDebugConfigurationError(isAndroidDebug: true, placeEmulator: true),
      contains('cannot be combined'),
    );
    expect(
      cloudDebugConfigurationError(
        isAndroidDebug: true,
        emulatorHostSpecified: true,
      ),
      contains('cannot be combined'),
    );
  });

  test('Android maps host loopback to the emulator bridge', () {
    expect(
      emulatorHostForPlatform('127.0.0.1', TargetPlatform.android),
      '10.0.2.2',
    );
    expect(
      emulatorHostForPlatform('10.0.2.2', TargetPlatform.android),
      '10.0.2.2',
    );
    expect(
      emulatorHostForPlatform('localhost', TargetPlatform.windows),
      'localhost',
    );
  });

  testWidgets(
    'sign-in, logout, and signing in again use the injected token claims',
    (tester) async {
      final auth = _SessionAuth();
      addTearDown(auth.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            firebaseAuth: auth,
            districtsStream: const Stream.empty(),
          ),
        ),
      );
      auth.events.add(null);
      await tester.pumpAndSettle();

      await _submitLogin(tester, 'admin@myyatra.test');
      expect(find.text('Manage Districts'), findsOneWidget);
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);

      await _submitLogin(tester, 'traveler@myyatra.test');
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Manage Districts'), findsNothing);
      await tester.ensureVisible(find.text('Refresh authorization'));
      await tester.tap(find.text('Refresh authorization'));
      await tester.pumpAndSettle();
      expect(auth.currentUser!.refreshed, isTrue);
      expect(find.text('Dashboard'), findsOneWidget);
    },
  );

  for (final (code, message) in [
    (
      'invalid-credential',
      'Local sign-in failed. Check the email and password, and confirm your saved demo accounts were imported.',
    ),
    (
      'wrong-password',
      'Local sign-in failed. Check the email and password, and confirm your saved demo accounts were imported.',
    ),
    (
      'user-not-found',
      'This account is missing from the local Auth Emulator. Start it with your saved demo data and try again.',
    ),
    (
      'network-request-failed',
      'Could not reach the local Auth Emulator. Start the demo emulators and try again.',
    ),
  ]) {
    testWidgets('local sign-in explains $code safely', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            auth: _RecordingAuth(code: code),
            useEmulator: true,
          ),
        ),
      );
      await _submitLogin(tester, 'traveler@myyatra.test');
      expect(find.text(message), findsOneWidget);
    });
  }

  group('LoginScreen', () {
    testWidgets('password is hidden by default and the eye icon toggles it', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      TextField passwordField() {
        return tester.widget<TextField>(find.byType(TextField).at(1));
      }

      expect(passwordField().obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      expect(passwordField().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();

      expect(passwordField().obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('shows validation messages for empty fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      final fields = find.byType(TextFormField);
      expect(
        tester.state<FormFieldState<String>>(fields.first).errorText,
        'Enter a valid email address',
      );
      expect(
        tester.state<FormFieldState<String>>(fields.last).errorText,
        'Enter your password',
      );
    });

    testWidgets('Forgot password link opens the recovery screen', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets('sign-in and password reset use the injected Firebase Auth', (
      tester,
    ) async {
      final auth = _RecordingAuth();
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
      await tester.enterText(
        find.byType(TextFormField).first,
        ' user@example.com ',
      );
      await tester.enterText(find.byType(TextFormField).last, 'test input');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(auth.signedInEmail, 'user@example.com');

      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(auth.resetEmail, 'user@example.com');
      expect(find.text('Check your inbox'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('pre-fills the email passed from the login screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            initialEmail: 'user@example.com',
            sendPasswordResetEmail: (_) async {},
          ),
        ),
      );

      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('rejects an invalid email without contacting Firebase', (
      tester,
    ) async {
      final sentTo = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            sendPasswordResetEmail: (email) async => sentTo.add(email),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(sentTo, isEmpty);
    });

    testWidgets('sends the reset email and shows the success message', (
      tester,
    ) async {
      final sentTo = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            sendPasswordResetEmail: (email) async => sentTo.add(email),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '  user@example.com ');
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(sentTo, ['user@example.com']);
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('user@example.com'), findsOneWidget);
    });

    testWidgets('shows a friendly message when no account is found', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            initialEmail: 'nobody@example.com',
            sendPasswordResetEmail: (_) async {
              throw FirebaseAuthException(code: 'user-not-found');
            },
          ),
        ),
      );

      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text('No account was found with that email address.'),
        findsOneWidget,
      );
      expect(find.text('Check your inbox'), findsNothing);
    });

    testWidgets('shows a connection message when the network fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            initialEmail: 'user@example.com',
            sendPasswordResetEmail: (_) async {
              throw FirebaseAuthException(code: 'network-request-failed');
            },
          ),
        ),
      );

      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text('Connection problem. Check your internet and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('"Use a different email" returns to the form', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            initialEmail: 'user@example.com',
            sendPasswordResetEmail: (_) async {},
          ),
        ),
      );

      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox'), findsOneWidget);

      await tester.ensureVisible(find.text('Use a different email'));
      await tester.tap(find.text('Use a different email'));
      await tester.pumpAndSettle();

      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
    });
  });
}

class _RecordingAuth extends Fake implements FirebaseAuth {
  _RecordingAuth({this.code = 'invalid-credential'});

  final String code;
  String? signedInEmail;
  String? resetEmail;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signedInEmail = email;
    throw FirebaseAuthException(code: code);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
  }
}

Future<void> _submitLogin(WidgetTester tester, String email) async {
  final fields = find.byType(TextFormField);
  await tester.ensureVisible(fields.first);
  await tester.enterText(fields.first, email);
  await tester.ensureVisible(fields.last);
  await tester.enterText(fields.last, 'test input');
  final submit = find.text('Sign in');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

class _SessionAuth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast();
  _ClaimUser? _user;

  @override
  _ClaimUser? get currentUser => _user;

  @override
  Stream<User?> idTokenChanges() => events.stream;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _user = _ClaimUser(email);
    events.add(_user);
    return _TestCredential();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    events.add(null);
  }
}

class _ClaimUser extends Fake implements User {
  _ClaimUser(this.email);

  @override
  final String email;
  bool refreshed = false;

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    refreshed |= forceRefresh;
    return _ClaimToken(email.startsWith('admin@'));
  }
}

class _ClaimToken extends Fake implements IdTokenResult {
  _ClaimToken(this.admin);

  final bool admin;

  @override
  Map<String, dynamic> get claims => {'admin': admin};
}

class _TestCredential extends Fake implements UserCredential {}

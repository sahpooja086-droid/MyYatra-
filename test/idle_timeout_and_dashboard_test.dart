import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/screens/auth/idle_timeout_gate.dart';
import 'package:myyatra/screens/dashboard/dashboard_screen.dart';

void main() {
  group('IdleTimeoutGate', () {
    Widget gate(VoidCallback onTimeout) {
      return MaterialApp(
        home: IdleTimeoutGate(
          timeout: const Duration(seconds: 10),
          onTimeout: onTimeout,
          child: const Scaffold(body: Text('content')),
        ),
      );
    }

    testWidgets('calls onTimeout once after the idle time has passed', (
      tester,
    ) async {
      var timeouts = 0;
      await tester.pumpWidget(gate(() => timeouts++));

      await tester.pump(const Duration(seconds: 9));
      expect(timeouts, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(timeouts, 1);

      await tester.pump(const Duration(seconds: 30));
      expect(timeouts, 1);
    });

    testWidgets('a touch restarts the countdown', (tester) async {
      var timeouts = 0;
      await tester.pumpWidget(gate(() => timeouts++));

      await tester.pump(const Duration(seconds: 8));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump(const Duration(seconds: 8));
      expect(timeouts, 0);

      await tester.pump(const Duration(seconds: 3));
      expect(timeouts, 1);
    });
  });

  group('DashboardScreen', () {
    testWidgets('shows who is signed in and calls onSignOut', (tester) async {
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            email: 'traveler@example.com',
            onSignOut: () => signedOut = true,
          ),
        ),
      );

      expect(find.text('Welcome to MyYatra'), findsOneWidget);
      expect(find.text('Signed in as traveler@example.com'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(signedOut, isTrue);
    });

    testWidgets('leaves out the email line when it is not known', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(onSignOut: () {})),
      );

      expect(find.textContaining('Signed in as'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}

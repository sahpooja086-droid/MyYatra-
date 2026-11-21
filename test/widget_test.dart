import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:myyatra/main.dart';

void main() {
  testWidgets('signed-out AuthGate shows the MyYatra login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authStateChanges: Stream<User?>.value(null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to MyYatra'), findsOneWidget);
    expect(find.text('Sign in to explore Nepal'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);
  });
}

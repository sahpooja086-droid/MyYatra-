import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/main.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/screens/auth/idle_timeout_gate.dart';
import 'package:myyatra/services/admin_authorization_service.dart';
import 'package:myyatra/services/district_mutation_service.dart';

import 'support/fake_district_mutation_service.dart';

void main() {
  testWidgets('shows checking state while admin claim is being resolved', (
    tester,
  ) async {
    final checker = _FakeAuthorizationChecker(pendingResult: Completer<bool>());
    await tester.pumpWidget(
      _app(signedInChanges: Stream<bool>.value(true), checker: checker),
    );
    await tester.pump();

    expect(find.text('Checking administrator authorization…'), findsOneWidget);

    checker.pendingResult!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Manage Districts'), findsOneWidget);
  });

  testWidgets('shows MyYatra login when signed out', (tester) async {
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(false),
        checker: _FakeAuthorizationChecker(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in to continue your Nepal story.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('returns to login after an authenticated user signs out', (
    tester,
  ) async {
    final authEvents = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: true),
      ),
    );

    authEvents.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Manage Districts'), findsOneWidget);

    authEvents.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    await authEvents.close();
  });

  testWidgets('signing out of Manage Places closes administrator routes', (
    tester,
  ) async {
    final authEvents = StreamController<bool>.broadcast();
    addTearDown(authEvents.close);
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: true),
        signOut: () async => authEvents.add(false),
      ),
    );
    authEvents.add(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-place-management')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Places'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.byKey(const Key('add-place-button')), findsNothing);
  });

  testWidgets('shows district management only for an admin', (tester) async {
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(result: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage Districts'), findsOneWidget);
    expect(find.text('Add District'), findsOneWidget);
    expect(find.byKey(const Key('district-search-field')), findsOneWidget);
  });

  testWidgets('authorized admin receives the injected mutation service', (
    tester,
  ) async {
    final service = FakeDistrictMutationService([_kaski()]);
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(result: true),
        mutationService: service,
        districts: [_kaski()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit district'), findsOneWidget);
    expect(find.byTooltip('Delete district'), findsOneWidget);
    expect(
      find.textContaining('Using the injected district service'),
      findsOneWidget,
    );
  });

  testWidgets('admin logout uses the injected callback without Firebase', (
    tester,
  ) async {
    var signOutCalled = false;
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(result: true),
        signOut: () async {
          signOutCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(signOutCalled, isTrue);
  });

  testWidgets('hides district management controls from non-admin users', (
    tester,
  ) async {
    final service = FakeDistrictMutationService([_kaski()]);
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(result: false),
        mutationService: service,
        districts: [_kaski()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to MyYatra'), findsOneWidget);
    expect(find.text('Manage Districts'), findsNothing);
    expect(find.text('Add District'), findsNothing);
    expect(find.byKey(const Key('open-place-management')), findsNothing);
    expect(find.byKey(const Key('district-search-field')), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(service.addCalls + service.updateCalls + service.deleteCalls, 0);
  });

  testWidgets('refreshes authorization from the non-admin dashboard', (
    tester,
  ) async {
    final checker = _FakeAuthorizationChecker(
      result: false,
      refreshedResult: true,
    );
    await tester.pumpWidget(
      _app(signedInChanges: Stream<bool>.value(true), checker: checker),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.ensureVisible(find.text('Refresh authorization'));
    await tester.tap(find.text('Refresh authorization'));
    await tester.pumpAndSettle();
    expect(checker.refreshRequested, isTrue);
    expect(find.byKey(const Key('open-place-management')), findsOneWidget);
  });

  testWidgets('shows a retryable message when authorization check fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(error: StateError('network')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authorization could not be checked'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Manage Districts'), findsNothing);
  });

  testWidgets('non-admin users land on the dashboard and can sign out', (
    tester,
  ) async {
    var signOutCalled = false;
    await tester.pumpWidget(
      _app(
        signedInChanges: Stream<bool>.value(true),
        checker: _FakeAuthorizationChecker(result: false),
        signOut: () async {
          signOutCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOutCalled, isTrue);
  });

  testWidgets('signs a regular user out after being idle and says why', (
    tester,
  ) async {
    final authEvents = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: false),
        signOut: () async => authEvents.add(false),
        idleTimeout: const Duration(seconds: 30),
      ),
    );
    authEvents.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MyYatra'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.textContaining('inactive'), findsOneWidget);
    expect(find.text('Welcome to MyYatra'), findsNothing);
    await authEvents.close();
  });

  testWidgets('signs an administrator out after being idle', (tester) async {
    final authEvents = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: true),
        signOut: () async => authEvents.add(false),
        idleTimeout: const Duration(seconds: 30),
      ),
    );
    authEvents.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Manage Districts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-place-management')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Places'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Manage Districts'), findsNothing);
    expect(find.text('Manage Places'), findsNothing);
    await authEvents.close();
  });

  testWidgets('a manual sign out does not show the inactivity notice', (
    tester,
  ) async {
    final authEvents = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: false),
        signOut: () async => authEvents.add(false),
      ),
    );
    authEvents.add(true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.textContaining('inactive'), findsNothing);
    await authEvents.close();
  });

  testWidgets('signing out closes screens opened on top of the dashboard', (
    tester,
  ) async {
    final authEvents = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      _app(
        signedInChanges: authEvents.stream,
        checker: _FakeAuthorizationChecker(result: false),
      ),
    );
    authEvents.add(true);
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('protected page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('protected page'), findsOneWidget);

    authEvents.add(false);
    await tester.pumpAndSettle();

    expect(find.text('protected page'), findsNothing);
    expect(find.text('Welcome back.'), findsOneWidget);
    await authEvents.close();
  });

  testWidgets(
    'touches on screens opened above the dashboard count as activity',
    (tester) async {
      final authEvents = StreamController<bool>.broadcast();
      await tester.pumpWidget(
        _app(
          signedInChanges: authEvents.stream,
          checker: _FakeAuthorizationChecker(result: false),
          signOut: () async => authEvents.add(false),
          idleTimeout: const Duration(seconds: 30),
        ),
      );
      authEvents.add(true);
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('form page')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 20));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('form page'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('form page'), findsNothing);
      expect(find.text('Welcome back.'), findsOneWidget);
      await authEvents.close();
    },
  );
}

Widget _app({
  required Stream<bool> signedInChanges,
  required AdminAuthorizationChecker checker,
  DistrictMutationService? mutationService,
  List<DistrictModel> districts = const [],
  Future<void> Function()? signOut,
  Duration? idleTimeout,
}) {
  return MaterialApp(
    home: AuthGate(
      signedInChanges: signedInChanges,
      authorizationChecker: checker,
      districtsStream: Stream<List<DistrictModel>>.value(districts),
      districtMutationService: mutationService,
      signOut: signOut ?? () async {},
      idleTimeout: idleTimeout ?? defaultIdleTimeout,
    ),
  );
}

DistrictModel _kaski() => DistrictModel(
  id: 'kaski',
  name: 'Kaski',
  province: 'Gandaki',
  description: 'Lake district',
  experienceTypes: const ['Nature'],
);

class _FakeAuthorizationChecker implements AdminAuthorizationChecker {
  _FakeAuthorizationChecker({
    this.result = false,
    this.refreshedResult,
    this.error,
    this.pendingResult,
  });

  final bool result;
  final bool? refreshedResult;
  final Object? error;
  final Completer<bool>? pendingResult;
  bool refreshRequested = false;

  @override
  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    if (forceRefresh) refreshRequested = true;
    if (error != null) throw error!;
    if (!forceRefresh && pendingResult != null) {
      return pendingResult!.future;
    }
    return forceRefresh ? (refreshedResult ?? result) : result;
  }
}

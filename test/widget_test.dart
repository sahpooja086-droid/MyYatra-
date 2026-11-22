import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/main.dart';
import 'package:myyatra/models/district_model.dart';
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

    expect(find.text('Welcome to MyYatra'), findsOneWidget);
    expect(find.text('Sign in to explore Nepal'), findsOneWidget);
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
    expect(find.text('Welcome to MyYatra'), findsOneWidget);
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
    expect(find.text('Welcome to MyYatra'), findsOneWidget);
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

    expect(find.text('Administrator access required'), findsOneWidget);
    expect(find.text('Manage Districts'), findsNothing);
    expect(find.text('Add District'), findsNothing);
    expect(find.byKey(const Key('district-search-field')), findsNothing);
    expect(find.byTooltip('Log out'), findsOneWidget);
    expect(service.addCalls + service.updateCalls + service.deleteCalls, 0);
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

  testWidgets('refreshes the token before rechecking non-admin access', (
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

    expect(find.text('Administrator access required'), findsOneWidget);
    await tester.tap(find.text('Refresh authorization'));
    await tester.pumpAndSettle();

    expect(checker.refreshRequested, isTrue);
    expect(find.text('Manage Districts'), findsOneWidget);
  });
}

Widget _app({
  required Stream<bool> signedInChanges,
  required AdminAuthorizationChecker checker,
  DistrictMutationService? mutationService,
  List<DistrictModel> districts = const [],
  Future<void> Function()? signOut,
}) {
  return MaterialApp(
    home: AuthGate(
      signedInChanges: signedInChanges,
      authorizationChecker: checker,
      districtsStream: Stream<List<DistrictModel>>.value(districts),
      districtMutationService: mutationService,
      signOut: signOut ?? () async {},
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

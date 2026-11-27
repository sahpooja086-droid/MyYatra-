import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/screens/admin/district_management_screen.dart';
import 'package:myyatra/services/district_service.dart';

import 'support/fake_district_mutation_service.dart';

void main() {
  testWidgets('Add form submits through the injected fake service', (
    tester,
  ) async {
    final service = FakeDistrictMutationService();
    await _showManagementScreen(tester, service: service);

    await tester.tap(find.text('Add District'));
    await tester.pumpAndSettle();
    await _completeAddForm(tester);

    expect(service.addCalls, 1);
    expect(service.districts['kathmandu']?.name, 'Kathmandu');
    expect(find.text('District added successfully.'), findsOneWidget);
  });

  testWidgets('Edit form submits through the injected fake service', (
    tester,
  ) async {
    final district = _kaski();
    final service = FakeDistrictMutationService([district]);
    await _showManagementScreen(
      tester,
      service: service,
      districts: [district],
    );

    await tester.tap(find.byTooltip('Edit district'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('district-description-field')),
      'Updated lake district',
    );
    await tester.tap(find.byKey(const Key('district-preview-button')));
    await tester.pumpAndSettle();

    expect(service.updateCalls, 1);
    expect(service.districts['kaski']?.description, 'Updated lake district');
    expect(find.text('District updated successfully.'), findsOneWidget);
  });

  testWidgets('confirmed Delete calls the injected fake service', (
    tester,
  ) async {
    final district = _kaski();
    final service = FakeDistrictMutationService([district]);
    await _showManagementScreen(
      tester,
      service: service,
      districts: [district],
    );

    await tester.tap(find.byTooltip('Delete district'));
    await tester.pumpAndSettle();
    expect(find.text('Delete district?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(service.districts, isEmpty);
    expect(find.text('District deleted successfully.'), findsOneWidget);
  });

  testWidgets('cancelling Delete leaves the district unchanged', (
    tester,
  ) async {
    final district = _kaski();
    final service = FakeDistrictMutationService([district]);
    await _showManagementScreen(
      tester,
      service: service,
      districts: [district],
    );

    await tester.tap(find.byTooltip('Delete district'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 0);
    expect(service.districts['kaski']?.name, 'Kaski');
  });

  testWidgets('service failure is shown to the administrator', (tester) async {
    final service = FakeDistrictMutationService()
      ..operationError = const DistrictServiceException('Test service failure');
    await _showManagementScreen(tester, service: service);

    await tester.tap(find.text('Add District'));
    await tester.pumpAndSettle();
    await _completeAddForm(tester);

    expect(service.districts, isEmpty);
    expect(find.text('Test service failure'), findsOneWidget);
  });

  testWidgets('non-admin is denied without initializing Firestore', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DistrictManagementScreen()),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Administrator authorization is required'),
      findsOneWidget,
    );
    expect(find.text('Add District'), findsNothing);
    expect(find.byTooltip('Edit district'), findsNothing);
    expect(find.byTooltip('Delete district'), findsNothing);
  });

  testWidgets('retry recreates an injected district stream without Firebase', (
    tester,
  ) async {
    final district = _kaski();
    final service = FakeDistrictMutationService();
    var streamAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DistrictManagementScreen(
          districtsStreamFactory: () {
            streamAttempts++;
            return streamAttempts == 1
                ? Stream<List<DistrictModel>>.error(Exception('temporary'))
                : Stream<List<DistrictModel>>.value([district]);
          },
          mutationService: service,
          isAdministrator: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('couldn’t load districts'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(streamAttempts, 2);
    expect(find.text('Kaski'), findsOneWidget);
  });
}

Future<void> _showManagementScreen(
  WidgetTester tester, {
  required FakeDistrictMutationService service,
  List<DistrictModel> districts = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DistrictManagementScreen(
        districtsStream: Stream<List<DistrictModel>>.value(districts),
        mutationService: service,
        isAdministrator: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _completeAddForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('district-description-field')),
    'Local Kathmandu description',
  );
  await tester.tap(find.byKey(const Key('district-province-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bagmati').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('district-dropdown-Bagmati')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kathmandu').last);
  await tester.pumpAndSettle();

  final nature = find.widgetWithText(FilterChip, 'Nature');
  await tester.ensureVisible(nature);
  await tester.pumpAndSettle();
  await tester.tap(nature);
  await tester.pumpAndSettle();

  final submit = find.byKey(const Key('district-preview-button'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

DistrictModel _kaski() => DistrictModel(
  id: 'kaski',
  name: 'Kaski',
  province: 'Gandaki',
  description: 'Lake district',
  experienceTypes: const ['Nature'],
);

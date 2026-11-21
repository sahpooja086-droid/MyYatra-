import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/screens/admin/district_management_screen.dart';

void main() {
  testWidgets('Add opens local form and preview is not added to the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DistrictManagementScreen(
          districtsStream: Stream.value(const []),
          isAdministrator: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add District'));
    await tester.pumpAndSettle();
    expect(find.text('Add District'), findsOneWidget);

    await _completeForm(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'District data validated locally. It was NOT saved to Firestore.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No districts yet. District information will appear here once it has '
        'been added.',
      ),
      findsOneWidget,
    );
    expect(find.text('New District'), findsNothing);
  });

  testWidgets('Edit opens form with district values and does not change list', (
    tester,
  ) async {
    final district = DistrictModel(
      id: 'kaski',
      name: 'Kaski',
      province: 'Gandaki',
      description: 'Lake and mountain scenery',
      experienceTypes: const ['Nature'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DistrictManagementScreen(
          districtsStream: Stream.value([district]),
          isAdministrator: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Preview district changes (not saved)'));
    await tester.pumpAndSettle();
    expect(find.text('Edit District'), findsOneWidget);
    expect(find.text('Gandaki'), findsOneWidget);
    expect(find.text('Lake and mountain scenery'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('district-dropdown-Gandaki')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Myagdi').last);
    await tester.pumpAndSettle();
    await _tapPreviewButton(tester);

    expect(
      find.text(
        'District data validated locally. It was NOT saved to Firestore.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kaski'), findsOneWidget);
    expect(find.text('Myagdi'), findsNothing);
  });
}

Future<void> _completeForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('district-description-field')),
    'Local preview description',
  );
  await tester.tap(find.byKey(const Key('district-province-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bagmati').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('district-dropdown-Bagmati')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kathmandu').last);
  await tester.pumpAndSettle();
  final natureChip = find.widgetWithText(FilterChip, 'Nature');
  await tester.ensureVisible(natureChip);
  await tester.pumpAndSettle();
  await tester.tap(natureChip);
  await tester.pumpAndSettle();
  await _tapPreviewButton(tester);
}

Future<void> _tapPreviewButton(WidgetTester tester) async {
  final previewButton = find.byKey(const Key('district-preview-button'));
  await tester.ensureVisible(previewButton);
  await tester.pumpAndSettle();
  await tester.tap(previewButton);
  await tester.pumpAndSettle();
}

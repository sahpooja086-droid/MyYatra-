import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/screens/admin/district_form_screen.dart';

void main() {
  group('DistrictFormRules', () {
    test('requires non-blank text and accepts trimmed text', () {
      expect(
        DistrictFormRules.validateRequiredText('   ', 'District name'),
        'District name is required',
      );
      expect(
        DistrictFormRules.validateRequiredText(' Kathmandu ', 'District name'),
        isNull,
      );
    });

    test('accepts only one of Nepal’s seven provinces', () {
      expect(DistrictFormRules.validateProvince(null), 'Province is required');
      expect(
        DistrictFormRules.validateProvince('Unknown Province'),
        'Select a supported province',
      );
      expect(DistrictFormRules.validateProvince('Bagmati'), isNull);
      expect(DistrictFormRules.provinces, hasLength(7));
    });

    test('requires supported experience values', () {
      expect(
        DistrictFormRules.validateExperienceTypes(const []),
        'Select at least one experience type',
      );
      expect(
        DistrictFormRules.validateExperienceTypes(const ['Other']),
        'Remove unsupported experience types',
      );
      expect(
        DistrictFormRules.validateExperienceTypes(const ['Nature', 'Food']),
        isNull,
      );
      expect(DistrictFormRules.experienceCategories, [
        'Nature',
        'Adventure',
        'Culture',
        'History',
        'Food',
        'Photography',
      ]);
    });
  });

  testWidgets('add form validates fields and filters by selected province',
      (tester) async {
    DistrictModel? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              Navigator.of(context)
                  .push<DistrictModel>(MaterialPageRoute(
                    builder: (_) => const DistrictFormScreen(),
                  ))
                  .then((value) => submitted = value);
            },
            child: const Text('Open form'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Add District'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('district-province-field')),
          )
          .initialValue,
      isNull,
    );

    await _tapPreviewButton(tester);
    final districtRequired = find.text('District name is required');
    await tester.scrollUntilVisible(
      districtRequired,
      -240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(districtRequired, findsOneWidget);
    await _expectVisibleValidation(tester, 'Province is required');
    await _expectVisibleValidation(tester, 'Description is required');
    await _expectVisibleValidation(
      tester,
      'Select at least one experience type',
    );

    final descriptionField =
        find.byKey(const Key('district-description-field'));
    await tester.ensureVisible(descriptionField);
    await tester.pumpAndSettle();
    await tester.enterText(
      descriptionField,
      '  A sample description.  ',
    );
    final provinceField = find.byKey(const Key('district-province-field'));
    await tester.ensureVisible(provinceField);
    await tester.pumpAndSettle();
    await tester.tap(provinceField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagmati').last);
    await tester.pumpAndSettle();

    final districtDropdown =
        find.byKey(const ValueKey('district-dropdown-Bagmati'));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(districtDropdown)
          .initialValue,
      isNull,
    );
    await tester.ensureVisible(districtDropdown);
    await tester.pumpAndSettle();
    await tester.tap(districtDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Kathmandu'), findsWidgets);
    expect(find.text('Kaski'), findsNothing);
    await tester.tap(find.text('Kathmandu').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(provinceField);
    await tester.pumpAndSettle();
    await tester.tap(provinceField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gandaki').last);
    await tester.pumpAndSettle();
    final gandakiDropdown =
        find.byKey(const ValueKey('district-dropdown-Gandaki'));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(gandakiDropdown)
          .initialValue,
      isNull,
    );
    await tester.ensureVisible(gandakiDropdown);
    await tester.pumpAndSettle();
    await tester.tap(gandakiDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Kaski'), findsOneWidget);
    expect(find.text('Kathmandu'), findsNothing);
    await tester.tap(find.text('Kaski').last);
    await tester.pumpAndSettle();

    final natureChip = find.widgetWithText(FilterChip, 'Nature');
    await tester.ensureVisible(natureChip);
    await tester.pumpAndSettle();
    await tester.tap(natureChip);
    await tester.pumpAndSettle();
    await _tapPreviewButton(tester);

    expect(submitted, isNotNull);
    expect(submitted!.name, 'Kaski');
    expect(submitted!.province, 'Gandaki');
    expect(submitted!.description, 'A sample description.');
    expect(submitted!.experienceTypes, ['Nature']);
    expect(submitted!.id, 'kaski');
  });

  testWidgets('edit form populates existing fields and selections',
      (tester) async {
    final district = DistrictModel(
      id: 'kaski',
      name: 'Kaski',
      province: 'Gandaki',
      description: 'Lake and mountain scenery',
      experienceTypes: const ['Nature', 'Photography'],
    );

    await tester.pumpWidget(MaterialApp(
      home: DistrictFormScreen(district: district),
    ));

    expect(find.text('Edit District'), findsOneWidget);
    expect(find.text('Gandaki'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('district-dropdown-Gandaki')),
          )
          .initialValue,
      'Kaski',
    );
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('district-description-field')),
      ).controller!.text,
      'Lake and mountain scenery',
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Nature'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Photography'))
          .selected,
      isTrue,
    );
  });

  testWidgets('legacy province and district mismatch shows validation notice',
      (tester) async {
    final legacyDistrict = DistrictModel(
      id: 'kaski',
      name: 'Kaski',
      province: 'Bagmati',
      description: 'Legacy mismatched record',
      experienceTypes: const ['Nature'],
    );

    await tester.pumpWidget(MaterialApp(
      home: DistrictFormScreen(district: legacyDistrict),
    ));

    expect(find.byKey(const Key('district-legacy-warning')), findsOneWidget);
    expect(
      find.text('"Kaski" belongs to Gandaki, not Bagmati. Select the correct '
          'province and district.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('district-dropdown-Bagmati')),
          )
          .initialValue,
      isNull,
    );
  });
}

Future<void> _tapPreviewButton(WidgetTester tester) async {
  final previewButton = find.byKey(const Key('district-preview-button'));
  await tester.ensureVisible(previewButton);
  await tester.pumpAndSettle();
  await tester.tap(previewButton);
  await tester.pumpAndSettle();
}

Future<void> _expectVisibleValidation(
  WidgetTester tester,
  String message,
) async {
  final validationMessage = find.text(message);
  await tester.ensureVisible(validationMessage);
  await tester.pumpAndSettle();
  expect(validationMessage, findsOneWidget);
}

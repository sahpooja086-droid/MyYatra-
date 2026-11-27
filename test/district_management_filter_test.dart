import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/screens/admin/district_management_screen.dart';

void main() {
  final districts = [
    _district('kathmandu', 'Kathmandu', 'Bagmati'),
    _district('chitwan', 'Chitwan', 'Bagmati'),
    _district('kaski', 'Kaski', 'Gandaki'),
  ];

  testWidgets('search finds names without case sensitivity', (tester) async {
    await _showScreen(tester, districts);

    await tester.enterText(
      find.byKey(const Key('district-search-field')),
      'kAtH',
    );
    await tester.pumpAndSettle();

    expect(find.text('Kathmandu'), findsOneWidget);
    expect(find.text('Chitwan'), findsNothing);
    expect(find.text('Kaski'), findsNothing);
  });

  testWidgets('province filter shows only districts from that province', (
    tester,
  ) async {
    await _showScreen(tester, districts);

    await _selectProvince(tester, 'Gandaki');

    expect(find.text('Kaski'), findsOneWidget);
    expect(find.text('Kathmandu'), findsNothing);
    expect(find.text('Chitwan'), findsNothing);
  });

  testWidgets('search and province filters work together', (tester) async {
    await _showScreen(tester, districts);

    await _selectProvince(tester, 'Bagmati');
    await tester.enterText(
      find.byKey(const Key('district-search-field')),
      'CHIT',
    );
    await tester.pumpAndSettle();

    expect(find.text('Chitwan'), findsOneWidget);
    expect(find.text('Kathmandu'), findsNothing);
    expect(find.text('Kaski'), findsNothing);
  });

  testWidgets('shows a helpful message when filters match no districts', (
    tester,
  ) async {
    await _showScreen(tester, districts);

    await tester.enterText(
      find.byKey(const Key('district-search-field')),
      'NoSuchDistrict',
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No districts match your search or province filter'),
      findsOneWidget,
    );
  });

  testWidgets('empty legacy fields display placeholders without mutation', (
    tester,
  ) async {
    final legacyDistrict = _district('legacy', '', '  ');
    await _showScreen(tester, [legacyDistrict]);

    expect(find.text('District name unavailable'), findsOneWidget);
    expect(find.text('Province unavailable'), findsOneWidget);
    expect(legacyDistrict.name, isEmpty);
    expect(legacyDistrict.province, '  ');
  });
}

Future<void> _showScreen(
  WidgetTester tester,
  List<DistrictModel> districts,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DistrictManagementScreen(
        districtsStream: Stream.value(districts),
        isAdministrator: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectProvince(WidgetTester tester, String province) async {
  await tester.tap(find.byKey(const Key('district-province-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(province).last);
  await tester.pumpAndSettle();
}

DistrictModel _district(String id, String name, String province) {
  return DistrictModel(
    id: id,
    name: name,
    province: province,
    description: '',
    experienceTypes: const [],
  );
}

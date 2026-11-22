import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/models/place_model.dart';
import 'package:myyatra/screens/admin/district_management_screen.dart';
import 'package:myyatra/screens/admin/place_form_screen.dart';
import 'package:myyatra/screens/admin/place_management_screen.dart';
import 'package:myyatra/services/place_data_validator.dart';
import 'package:myyatra/services/place_service.dart';

final _kathmandu = DistrictModel(
  id: 'kathmandu',
  name: 'Kathmandu',
  province: 'Bagmati',
  description: 'Capital district',
  experienceTypes: const ['Culture'],
);

final _pokharaDistrict = DistrictModel(
  id: 'kaski',
  name: 'Kaski',
  province: 'Gandaki',
  description: 'Mountain district',
  experienceTypes: const ['Nature'],
);

final _places = [
  const PlaceModel(
    id: 'kathmandu--pashupatinath-temple',
    name: 'Pashupatinath Temple',
    category: 'Temple',
    districtId: 'kathmandu',
    description: 'Historic temple',
  ),
  const PlaceModel(
    id: 'kaski--sarangkot',
    name: 'Sarangkot',
    category: 'Viewpoint',
    districtId: 'kaski',
    description: 'Mountain viewpoint',
  ),
];

void main() {
  testWidgets(
    'emulator form saves and edits with snapshot updates, then confirms deletion',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _WidgetPlaceService();
      addTearDown(service.snapshots.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PlaceManagementScreen(
            initialDistricts: [_kathmandu],
            isAdministrator: true,
            placesStreamFactory: service.getPlaces,
            placeMutations: () => service,
          ),
        ),
      );
      await tester.pump();
      service.emit();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-place-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-name-field')),
        'QA Place',
      );
      await tester.enterText(
        find.byKey(const Key('place-category-field')),
        'Temple',
      );
      await tester.tap(find.byKey(const Key('place-district-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kathmandu (Bagmati)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-description-field')),
        'Sample description',
      );
      await tester.enterText(
        find.byKey(const Key('place-image-url-field')),
        'https://example.com/place.jpg',
      );
      await tester.tap(find.text('Save Place'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      service.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Place added successfully.'), findsOneWidget);
      expect(find.text('QA Place'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit place'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-image-url-field')),
        '',
      );
      service.pending = Completer<void>();
      await tester.tap(find.text('Save Place'));
      await tester.pump();
      service.pending.completeError(
        const PlaceServiceException('Try the save again.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try the save again.'), findsOneWidget);
      expect(service.record?.imageUrl, 'https://example.com/place.jpg');

      service.pending = Completer<void>()..complete();
      await tester.tap(find.text('Save Place'));
      await tester.pumpAndSettle();
      expect(find.text('Place updated successfully.'), findsOneWidget);
      expect(service.record?.imageUrl, isNull);

      await tester.tap(find.byTooltip('Delete place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.record, isNotNull);
      await tester.tap(find.byTooltip('Delete place'));
      await tester.pumpAndSettle();
      service.pending = Completer<void>();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      service.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Place deleted successfully.'), findsOneWidget);
      expect(find.text('QA Place'), findsNothing);
    },
  );

  testWidgets(
    'live place snapshots update the list and keep search and district filters',
    (tester) async {
      final snapshots = StreamController<List<PlaceModel>>();
      addTearDown(snapshots.close);

      await tester.pumpWidget(
        MaterialApp(
          home: PlaceManagementScreen(
            initialDistricts: [_kathmandu, _pokharaDistrict],
            initialPlaces: [_places.first],
            placesStreamFactory: () => snapshots.stream,
            isAdministrator: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('place-list-loading')), findsOneWidget);
      expect(find.text('Pashupatinath Temple'), findsNothing);

      snapshots.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No places found in the demo emulator.'),
        findsOneWidget,
      );

      snapshots.add(_places);
      await tester.pumpAndSettle();
      expect(find.text('Pashupatinath Temple'), findsOneWidget);
      expect(find.text('Sarangkot'), findsOneWidget);

      await tester.tap(find.byKey(const Key('place-district-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaski').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-search-field')),
        'SARAN',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sarangkot'), findsOneWidget);
      expect(find.text('Pashupatinath Temple'), findsNothing);

      snapshots.add([_places.first]);
      await tester.pumpAndSettle();
      expect(
        find.text('No places match your search or district filter.'),
        findsOneWidget,
      );
      snapshots.add(_places);
      await tester.pumpAndSettle();
      expect(find.text('Sarangkot'), findsOneWidget);
      expect(find.text('Pashupatinath Temple'), findsNothing);
    },
  );

  testWidgets('live place errors can be retried with a fresh stream', (
    tester,
  ) async {
    final first = StreamController<List<PlaceModel>>();
    final retry = StreamController<List<PlaceModel>>();
    addTearDown(first.close);
    addTearDown(retry.close);
    var requests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PlaceManagementScreen(
          initialDistricts: [_kathmandu],
          placesStreamFactory: () =>
              requests++ == 0 ? first.stream : retry.stream,
          isAdministrator: true,
        ),
      ),
    );
    await tester.pump();
    first.addError(StateError('Connection lost'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load places from the demo emulator.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('retry-place-list')));
    await tester.pump();
    expect(find.byKey(const Key('place-list-loading')), findsOneWidget);
    retry.add([_places.first]);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Pashupatinath Temple'), findsOneWidget);
    expect(find.byKey(const Key('retry-place-list')), findsNothing);
  });

  group('PlaceDataValidator', () {
    test('trims place fields and requires name, district, and description', () {
      final normalized = PlaceDataValidator.normalize(
        const PlaceModel(
          id: '',
          name: '  Patan Durbar Square  ',
          category: ' Heritage ',
          districtId: 'kathmandu',
          description: '  Heritage site  ',
        ),
        districts: [_kathmandu],
        isCreate: true,
      );
      expect(normalized.name, 'Patan Durbar Square');
      expect(normalized.category, 'Heritage');
      expect(normalized.id, 'kathmandu--patan-durbar-square');
      expect(normalized.description, 'Heritage site');

      expect(
        () => PlaceDataValidator.normalize(
          const PlaceModel(
            id: '',
            name: '  ',
            category: 'Heritage',
            districtId: 'kathmandu',
            description: 'Valid',
          ),
          districts: [_kathmandu],
          isCreate: true,
        ),
        throwsA(isA<PlaceValidationException>()),
      );
    });

    test('rejects unsupported districts and unreasonable lengths', () {
      expect(
        () => PlaceDataValidator.normalize(
          const PlaceModel(
            id: '',
            name: 'Place',
            category: 'Museum',
            districtId: 'not-a-district',
            description: 'Details',
          ),
          districts: [_kathmandu],
          isCreate: true,
        ),
        throwsA(isA<PlaceValidationException>()),
      );
      expect(
        () => PlaceDataValidator.normalize(
          PlaceModel(
            id: '',
            name: List.filled(121, 'P').join(),
            category: 'Museum',
            districtId: 'kathmandu',
            description: 'Details',
          ),
          districts: [_kathmandu],
          isCreate: true,
        ),
        throwsA(isA<PlaceValidationException>()),
      );
    });

    test('requires a category and accepts only HTTPS image URLs', () {
      expect(
        () => PlaceDataValidator.normalize(
          const PlaceModel(
            id: '',
            name: 'Patan Museum',
            category: '  ',
            districtId: 'kathmandu',
            description: 'Museum details',
          ),
          districts: [_kathmandu],
          isCreate: true,
        ),
        throwsA(isA<PlaceValidationException>()),
      );
      expect(
        () => PlaceDataValidator.normalize(
          const PlaceModel(
            id: '',
            name: 'Patan Museum',
            category: 'Museum',
            districtId: 'kathmandu',
            description: 'Museum details',
            imageUrl: 'http://example.com/image.jpg',
          ),
          districts: [_kathmandu],
          isCreate: true,
        ),
        throwsA(isA<PlaceValidationException>()),
      );
    });
  });

  testWidgets('place list searches and filters together by district', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceManagementScreen(
          isAdministrator: true,
          districtsStream: Stream.value([_kathmandu, _pokharaDistrict]),
          initialPlaces: _places,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pashupatinath Temple'), findsOneWidget);
    expect(find.text('Sarangkot'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('place-search-field')), 'sar');
    await tester.pumpAndSettle();
    expect(find.text('Sarangkot'), findsOneWidget);
    expect(find.text('Pashupatinath Temple'), findsNothing);

    await tester.enterText(find.byKey(const Key('place-search-field')), '');
    await tester.tap(find.byKey(const Key('place-district-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kathmandu').last);
    await tester.pumpAndSettle();
    expect(find.text('Pashupatinath Temple'), findsOneWidget);
    expect(find.text('Sarangkot'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'pashu',
    );
    await tester.pumpAndSettle();
    expect(find.text('Pashupatinath Temple'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'no match',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No places match your search or district filter.'),
      findsOneWidget,
    );
  });

  testWidgets('district administrator can open the places screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DistrictManagementScreen(
          isAdministrator: true,
          districtsStream: Stream.value([_kathmandu]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-place-management')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Places'), findsOneWidget);
    expect(find.text('No place records are connected yet.'), findsNothing);
    expect(
      find.textContaining('No place records are connected yet.'),
      findsOneWidget,
    );
  });

  testWidgets('edit form pre-fills values and previews without saving', (
    tester,
  ) async {
    PlaceModel? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PlaceModel>(
                  MaterialPageRoute(
                    builder: (_) => PlaceFormScreen(
                      districts: [_kathmandu],
                      place: _places.first,
                    ),
                  ),
                );
              },
              child: const Text('Open place form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open place form'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Place'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('place-name-field')))
          .controller!
          .text,
      'Pashupatinath Temple',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('place-category-field')))
          .controller!
          .text,
      'Temple',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('place-district-field')),
          )
          .initialValue,
      'kathmandu',
    );
    await _scrollToPlacePreview(tester);
    await tester.tap(find.byKey(const Key('place-preview-button')));
    await tester.pumpAndSettle();
    expect(result?.id, 'kathmandu--pashupatinath-temple');
  });

  testWidgets('add form displays required-field validation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PlaceFormScreen(districts: [_kathmandu])),
    );
    await _scrollToPlacePreview(tester);
    final previewButton = find.byKey(const Key('place-preview-button'));
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    expect(find.text('Place name is required.'), findsOneWidget);
    expect(find.text('Category is required.'), findsOneWidget);
    expect(find.text('Select a district.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
  });

  testWidgets('add place only previews validated data and does not add it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceManagementScreen(
          isAdministrator: true,
          districtsStream: Stream.value([_kathmandu]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-place-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('place-name-field')),
      'Patan Durbar Square',
    );
    await tester.enterText(
      find.byKey(const Key('place-category-field')),
      'Heritage',
    );
    await tester.tap(find.byKey(const Key('place-district-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kathmandu (Bagmati)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('place-description-field')),
      'Historic palace square',
    );
    await _scrollToPlacePreview(tester);
    final previewButton = find.byKey(const Key('place-preview-button'));
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Place data validated locally. It was NOT saved to Firestore.'),
      findsOneWidget,
    );
    expect(find.text('No place records are connected yet.'), findsNothing);
    expect(
      find.textContaining('No place records are connected yet.'),
      findsOneWidget,
    );
  });

  testWidgets('delete preview cancellation and confirmation never delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceManagementScreen(
          isAdministrator: true,
          districtsStream: Stream.value([_kathmandu]),
          initialPlaces: [_places.first],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete-place-kathmandu--pashupatinath-temple')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Pashupatinath Temple'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('delete-place-kathmandu--pashupatinath-temple')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Pashupatinath Temple'), findsOneWidget);
    expect(
      find.text('Deletion preview confirmed. No place was deleted.'),
      findsOneWidget,
    );
  });

  testWidgets('non-admin cannot access place actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlaceManagementScreen(isAdministrator: false)),
    );
    expect(
      find.text('Administrator authorization is required to manage places.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-place-button')), findsNothing);
  });
}

class _WidgetPlaceService implements PlaceService {
  final snapshots = StreamController<List<PlaceModel>>();
  Completer<void> pending = Completer<void>();
  PlaceModel? record;

  void emit() => snapshots.add([?record]);

  @override
  Stream<List<PlaceModel>> getPlaces() => snapshots.stream;

  @override
  Future<PlaceModel?> getPlace(String id) async =>
      record?.id == id ? record : null;

  @override
  Future<void> addPlace(PlaceModel place) => updatePlace(place);

  @override
  Future<void> updatePlace(PlaceModel place) async {
    await pending.future;
    record = place;
    emit();
  }

  @override
  Future<void> deletePlace(String id) async {
    await pending.future;
    assert(record?.id == id);
    record = null;
    emit();
  }
}

Future<void> _scrollToPlacePreview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('place-preview-button')),
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

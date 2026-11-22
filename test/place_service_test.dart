import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/models/place_model.dart';
import 'package:myyatra/services/place_data_validator.dart';
import 'package:myyatra/services/place_service.dart';

void main() {
  final kaski = DistrictModel(
    id: 'kaski',
    name: 'Kaski',
    province: 'Gandaki',
    description: 'District',
    experienceTypes: const ['Nature'],
  );

  test('PlaceModel serializes required and optional fields safely', () {
    final place = PlaceModel.fromMap('kaski--sarangkot', {
      'name': 'Sarangkot',
      'category': 'Viewpoint',
      'districtId': 'kaski',
      'description': 'Mountain view',
      'imageUrl': 'https://example.com/sarangkot.jpg',
      'updatedAt': DateTime.utc(2026, 1, 2),
    });
    final serialized = place.toFirestore();

    expect(place.id, 'kaski--sarangkot');
    expect(place.category, 'Viewpoint');
    expect(place.imageUrl, 'https://example.com/sarangkot.jpg');
    expect(serialized['name'], 'Sarangkot');
    expect(serialized['districtId'], 'kaski');
    expect(serialized['category'], 'Viewpoint');
    expect(serialized['imageUrl'], 'https://example.com/sarangkot.jpg');
    expect(serialized.containsKey('updatedAt'), isTrue);
  });

  test('add uses canonical ID and duplicate add does not overwrite', () async {
    final repository = _FakePlaceRepository({'kaski': kaski});
    final service = PlaceService(repository: repository);
    await service.addPlace(_place(id: '', description: 'First description'));

    final canonicalId = 'kaski--sarangkot';
    expect(repository.places[canonicalId]?.description, 'First description');
    await expectLater(
      service.addPlace(_place(id: '', description: 'Replacement description')),
      throwsA(isA<PlaceDuplicateException>()),
    );
    expect(repository.places[canonicalId]?.description, 'First description');
  });

  test(
    'update allows content changes while preserving canonical identity',
    () async {
      final repository = _FakePlaceRepository({'kaski': kaski});
      final service = PlaceService(repository: repository);
      await service.addPlace(_place(id: ''));
      await service.updatePlace(
        _place(
          id: 'kaski--sarangkot',
          category: 'Viewpoint and hiking',
          description: 'Updated details',
          imageUrl: 'https://example.com/new.jpg',
        ),
      );

      final saved = repository.places['kaski--sarangkot']!;
      expect(saved.name, 'Sarangkot');
      expect(saved.districtId, 'kaski');
      expect(saved.category, 'Viewpoint and hiking');
      expect(saved.description, 'Updated details');
      expect(saved.imageUrl, 'https://example.com/new.jpg');

      await service.updatePlace(
        _place(id: 'kaski--sarangkot', imageUrl: '   '),
      );
      expect(repository.places['kaski--sarangkot']?.imageUrl, isNull);
    },
  );

  test('update rejects an attempted identity change', () async {
    final repository = _FakePlaceRepository({'kaski': kaski});
    final service = PlaceService(repository: repository);
    await service.addPlace(_place(id: ''));
    await expectLater(
      service.updatePlace(
        _place(id: 'kaski--sarangkot', name: 'Different Name'),
      ),
      throwsA(isA<PlaceValidationException>()),
    );
  });

  test('delete removes a valid record but refuses a legacy ID', () async {
    final repository = _FakePlaceRepository({'kaski': kaski});
    final service = PlaceService(repository: repository);
    await service.addPlace(_place(id: ''));
    await service.deletePlace('kaski--sarangkot');
    expect(repository.places, isEmpty);

    repository.places['legacy-place'] = _place(
      id: 'legacy-place',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await expectLater(
      service.deletePlace('legacy-place'),
      throwsA(isA<PlaceLegacyRecordException>()),
    );
    expect(repository.places.containsKey('legacy-place'), isTrue);
  });

  test('writes require an existing canonical district reference', () async {
    final repository = _FakePlaceRepository({});
    final service = PlaceService(repository: repository);
    await expectLater(
      service.addPlace(_place(id: '')),
      throwsA(isA<PlaceValidationException>()),
    );
    expect(repository.places, isEmpty);
  });

  test(
    'a failed emulator verification blocks all mutations and preserves reads',
    () async {
      final repository = _FakePlaceRepository({'kaski': kaski});
      const id = 'kaski--sarangkot';
      await repository.create(_place(id: id));
      final service = PlaceService(
        repository: repository,
        beforeMutation: () async =>
            throw const PlaceServiceException('Unverified emulator'),
      );
      final original = await service.getPlace(id);
      for (final mutate in <Future<void> Function()>[
        () => service.addPlace(_place(id: '', name: 'Other Place')),
        () => service.updatePlace(_place(id: id, description: 'Changed')),
        () => service.deletePlace(id),
      ]) {
        await expectLater(mutate(), throwsA(isA<PlaceServiceException>()));
      }
      expect(await service.getPlace(id), same(original));
      expect(await service.getPlaces().first, [original]);
    },
  );
}

PlaceModel _place({
  required String id,
  String name = 'Sarangkot',
  String category = 'Viewpoint',
  String districtId = 'kaski',
  String description = 'Mountain view',
  String? imageUrl,
  DateTime? updatedAt,
}) {
  return PlaceModel(
    id: id,
    name: name,
    category: category,
    districtId: districtId,
    description: description,
    imageUrl: imageUrl,
    updatedAt: updatedAt,
  );
}

class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository(this.districts);

  final Map<String, DistrictModel> districts;
  final Map<String, PlaceModel> places = {};

  @override
  Stream<List<PlaceModel>> watchAll() => Stream.value(places.values.toList());

  @override
  Future<PlaceModel?> getById(String id) async => places[id];

  @override
  Future<DistrictModel?> getDistrictById(String id) async => districts[id];

  @override
  Future<void> create(PlaceModel place) async {
    if (places.containsKey(place.id)) {
      throw PlaceDuplicateException(place.name);
    }
    places[place.id] = PlaceModel(
      id: place.id,
      name: place.name,
      category: place.category,
      districtId: place.districtId,
      description: place.description,
      imageUrl: place.imageUrl,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
  }

  @override
  Future<void> update(PlaceModel place) async {
    if (!places.containsKey(place.id)) throw PlaceNotFoundException(place.id);
    places[place.id] = PlaceModel(
      id: place.id,
      name: place.name,
      category: place.category,
      districtId: place.districtId,
      description: place.description,
      imageUrl: place.imageUrl,
      updatedAt: DateTime.utc(2026, 1, 3),
    );
  }

  @override
  Future<void> delete(String id) async {
    if (places.remove(id) == null) throw PlaceNotFoundException(id);
  }
}

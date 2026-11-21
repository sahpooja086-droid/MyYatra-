import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/data/nepal_district_directory.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/services/district_data_validator.dart';
import 'package:myyatra/services/district_service.dart';

void main() {
  group('DistrictModel Firestore conversion', () {
    test('converts document fields and Firestore timestamp', () {
      final updatedAt = DateTime.utc(2026, 1, 2, 3, 4);
      final model = DistrictModel.fromMap('kaski', {
        'name': 'Kaski',
        'province': 'Gandaki',
        'description': 'Lake district',
        'experienceTypes': ['Nature', 'Photography'],
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(model.id, 'kaski');
      expect(model.name, 'Kaski');
      expect(model.province, 'Gandaki');
      expect(model.description, 'Lake district');
      expect(model.experienceTypes, ['Nature', 'Photography']);
      expect(model.updatedAt!.isAtSameMomentAs(updatedAt), isTrue);
    });

    test('serializes district fields and requests a server timestamp', () {
      final data = _district(
        id: 'kaski',
        name: 'Kaski',
        province: 'Gandaki',
        description: 'Lake district',
        experienceTypes: const ['Nature'],
      ).toFirestore();

      expect(data, containsPair('name', 'Kaski'));
      expect(data, containsPair('province', 'Gandaki'));
      expect(data, containsPair('description', 'Lake district'));
      expect(data, containsPair('experienceTypes', ['Nature']));
      expect(data['updatedAt'], isA<FieldValue>());
      expect(
        data.containsKey('id'),
        isFalse,
      ); // Document ID is the district ID.
    });

    test('reads malformed legacy fields safely without inventing values', () {
      final model = DistrictModel.fromMap('legacy', {
        'name': null,
        'province': 4,
        'description': null,
        'experienceTypes': ['Nature', 12],
        'updatedAt': 'unknown',
      });

      expect(model.id, 'legacy');
      expect(model.name, isEmpty);
      expect(model.province, isEmpty);
      expect(model.description, isEmpty);
      expect(model.experienceTypes, ['Nature']);
      expect(model.updatedAt, isNull);
    });
  });

  group('DistrictService validation and writes', () {
    test('creates only normalized data at the stable canonical ID', () async {
      final repository = _FakeDistrictRepository();
      final service = DistrictService(repository: repository);

      await service.addDistrict(
        _district(
          id: 'kaski',
          name: ' KASKI ',
          province: ' gandaki ',
          description: '  Lake district  ',
          experienceTypes: const [' Nature ', 'Food'],
        ),
      );

      final saved = repository.documents['kaski'];
      expect(saved, isNotNull);
      expect(saved!.name, 'Kaski');
      expect(saved.province, 'Gandaki');
      expect(saved.description, 'Lake district');
      expect(saved.experienceTypes, ['Nature', 'Food']);
      expect(repository.createCalls, 1);
    });

    test(
      'rejects duplicate canonical district without overwriting records',
      () async {
        final repository = _FakeDistrictRepository()
          ..documents['legacy-kaski'] = _district(
            id: 'legacy-kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Existing record',
            experienceTypes: const ['Nature'],
          );
        final service = DistrictService(repository: repository);

        await expectLater(
          service.addDistrict(
            _district(
              id: 'kaski',
              name: 'Kaski',
              province: 'Gandaki',
              description: 'New record',
              experienceTypes: const ['Culture'],
            ),
          ),
          throwsA(isA<DistrictDuplicateException>()),
        );

        expect(repository.documents, hasLength(1));
        expect(
          repository.documents['legacy-kaski']!.description,
          'Existing record',
        );
        expect(repository.createCalls, 0);
      },
    );

    test('rejects invalid district and province combinations', () async {
      final repository = _FakeDistrictRepository();
      final service = DistrictService(repository: repository);

      await expectLater(
        service.addDistrict(
          _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Bagmati',
            description: 'Description',
            experienceTypes: const ['Nature'],
          ),
        ),
        throwsA(isA<DistrictValidationException>()),
      );
      expect(repository.createCalls, 0);
    });

    test('rejects a noncanonical ID for a new district', () async {
      final repository = _FakeDistrictRepository();
      final service = DistrictService(repository: repository);

      await expectLater(
        service.addDistrict(
          _district(
            id: 'legacy-kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Description',
            experienceTypes: const ['Nature'],
          ),
        ),
        throwsA(isA<DistrictValidationException>()),
      );
      expect(repository.createCalls, 0);
    });

    test(
      'rejects unknown districts, empty required text, and unsupported types',
      () async {
        final repository = _FakeDistrictRepository();
        final service = DistrictService(repository: repository);

        final invalidRecords = [
          _district(
            id: 'not-a-district',
            name: 'Atlantis',
            province: 'Gandaki',
            description: 'Description',
            experienceTypes: const ['Nature'],
          ),
          _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: '  ',
            experienceTypes: const ['Nature'],
          ),
          _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Description',
            experienceTypes: const ['Other'],
          ),
          _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Description',
            experienceTypes: const ['Nature', 'Nature'],
          ),
        ];

        for (final invalidRecord in invalidRecords) {
          await expectLater(
            service.addDistrict(invalidRecord),
            throwsA(isA<DistrictValidationException>()),
          );
        }
        expect(repository.createCalls, 0);
      },
    );

    test(
      'rejects an update to a legacy document ID for administrator review',
      () async {
        final repository = _FakeDistrictRepository()
          ..documents['old-kaski-id'] = _district(
            id: 'old-kaski-id',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Old description',
            experienceTypes: const ['Nature'],
          );
        final service = DistrictService(repository: repository);

        await expectLater(
          service.updateDistrict(
            _district(
              id: 'old-kaski-id',
              name: 'Kaski',
              province: 'Gandaki',
              description: '  Updated description  ',
              experienceTypes: const ['Culture'],
            ),
          ),
          throwsA(
            isA<DistrictLegacyRecordException>().having(
              (error) => error.message,
              'message',
              allOf(contains('legacy document ID'), contains('administrator')),
            ),
          ),
        );

        expect(repository.documents.keys, ['old-kaski-id']);
        expect(
          repository.documents['old-kaski-id']!.description,
          'Old description',
        );
        expect(repository.updateCalls, 0);
        expect(repository.createCalls, 0);
      },
    );

    test(
      'updates an existing canonical district without changing its ID',
      () async {
        final repository = _FakeDistrictRepository()
          ..documents['kaski'] = _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Old description',
            experienceTypes: const ['Nature'],
          );
        final service = DistrictService(repository: repository);

        await service.updateDistrict(
          _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: '  Updated description  ',
            experienceTypes: const ['Culture'],
          ),
        );

        expect(repository.documents.keys, ['kaski']);
        expect(
          repository.documents['kaski']!.description,
          'Updated description',
        );
        expect(repository.updateCalls, 1);
        expect(repository.createCalls, 0);
      },
    );

    test(
      'refuses to change the identity of an existing district record',
      () async {
        final repository = _FakeDistrictRepository()
          ..documents['kaski'] = _district(
            id: 'kaski',
            name: 'Kaski',
            province: 'Gandaki',
            description: 'Original record',
            experienceTypes: const ['Nature'],
          );
        final service = DistrictService(repository: repository);

        await expectLater(
          service.updateDistrict(
            _district(
              id: 'kaski',
              name: 'Kathmandu',
              province: 'Bagmati',
              description: 'Attempted reassignment',
              experienceTypes: const ['Culture'],
            ),
          ),
          throwsA(isA<DistrictValidationException>()),
        );

        expect(repository.documents.keys, ['kaski']);
        expect(repository.documents['kaski']!.name, 'Kaski');
        expect(
          repository.documents['kaski']!.description,
          'Original record',
        );
        expect(repository.updateCalls, 0);
      },
    );

    test('deletes only the requested existing document', () async {
      final repository = _FakeDistrictRepository()
        ..documents['legacy-kaski'] = _district(
          id: 'legacy-kaski',
          name: 'Kaski',
          province: 'Gandaki',
          description: 'Existing record',
          experienceTypes: const ['Nature'],
        );
      final service = DistrictService(repository: repository);

      await service.deleteDistrict('legacy-kaski');

      expect(repository.documents, isEmpty);
      expect(repository.deleteCalls, 1);
    });

    test('returns friendly permission and network messages', () async {
      final permissionRepository = _FakeDistrictRepository()
        ..createError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      final permissionService = DistrictService(
        repository: permissionRepository,
      );
      await expectLater(
        permissionService.addDistrict(_validKaski()),
        throwsA(
          isA<DistrictServiceException>().having(
            (error) => error.message,
            'message',
            contains('permission'),
          ),
        ),
      );

      final networkRepository = _FakeDistrictRepository()
        ..createError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      final networkService = DistrictService(repository: networkRepository);
      await expectLater(
        networkService.addDistrict(_validKaski()),
        throwsA(
          isA<DistrictServiceException>().having(
            (error) => error.message,
            'message',
            contains('internet connection'),
          ),
        ),
      );
    });
  });
}

DistrictModel _validKaski() => _district(
  id: 'kaski',
  name: 'Kaski',
  province: 'Gandaki',
  description: 'Lake district',
  experienceTypes: const ['Nature'],
);

DistrictModel _district({
  required String id,
  required String name,
  required String province,
  required String description,
  required List<String> experienceTypes,
}) {
  return DistrictModel(
    id: id,
    name: name,
    province: province,
    description: description,
    experienceTypes: experienceTypes,
  );
}

class _FakeDistrictRepository implements DistrictRepository {
  final Map<String, DistrictModel> documents = {};
  Object? createError;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Stream<List<DistrictModel>> watchAll() =>
      Stream.value(documents.values.toList());

  @override
  Future<DistrictModel?> getById(String id) async => documents[id];

  @override
  Future<bool> containsDistrict(
    NepalDistrict district, {
    String? excludingDocumentId,
  }) async {
    return documents.entries.any((entry) {
      if (entry.key == excludingDocumentId) return false;
      final canonical =
          NepalDistrictDirectory.byId(entry.key) ??
          NepalDistrictDirectory.byName(entry.value.name);
      return canonical?.id == district.id;
    });
  }

  @override
  Future<void> create(DistrictModel district) async {
    final error = createError;
    if (error != null) throw error;
    if (documents.containsKey(district.id)) {
      throw DistrictDuplicateException(district.name);
    }
    createCalls++;
    documents[district.id] = district;
  }

  @override
  Future<void> update(DistrictModel district) async {
    if (!documents.containsKey(district.id)) {
      throw DistrictNotFoundException(district.id);
    }
    updateCalls++;
    documents[district.id] = district;
  }

  @override
  Future<void> delete(String id) async {
    if (!documents.containsKey(id)) throw DistrictNotFoundException(id);
    deleteCalls++;
    documents.remove(id);
  }
}

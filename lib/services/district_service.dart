import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/nepal_district_directory.dart';
import '../models/district_model.dart';
import 'district_data_validator.dart';
import 'district_mutation_service.dart';

abstract interface class DistrictRepository {
  Stream<List<DistrictModel>> watchAll();

  Future<DistrictModel?> getById(String id);

  Future<bool> containsDistrict(
    NepalDistrict district, {
    String? excludingDocumentId,
  });

  Future<void> create(DistrictModel district);

  Future<void> update(DistrictModel district);

  Future<void> delete(String id);
}

class DistrictServiceException implements Exception {
  const DistrictServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DistrictDuplicateException extends DistrictServiceException {
  const DistrictDuplicateException(String districtName)
    : super('$districtName already exists. Existing data was not changed.');
}

class DistrictNotFoundException extends DistrictServiceException {
  const DistrictNotFoundException(String id)
    : super('District “$id” was not found.');
}

class DistrictLegacyRecordException extends DistrictServiceException {
  const DistrictLegacyRecordException(String districtName)
    : super(
        '$districtName uses a legacy document ID. An administrator must '
        'review this record before it can be updated.',
      );
}

class FirestoreDistrictRepository implements DistrictRepository {
  FirestoreDistrictRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _districts =>
      _firestore.collection('districts');

  @override
  Stream<List<DistrictModel>> watchAll() {
    return _districts.snapshots().map(
      (snapshot) => snapshot.docs
          .map(DistrictModel.fromFirestore)
          .toList(growable: false),
    );
  }

  @override
  Future<DistrictModel?> getById(String id) async {
    final document = await _districts.doc(id).get();
    if (!document.exists) return null;
    return DistrictModel.fromFirestore(document);
  }

  @override
  Future<bool> containsDistrict(
    NepalDistrict district, {
    String? excludingDocumentId,
  }) async {
    final snapshot = await _districts.get();
    for (final document in snapshot.docs) {
      if (document.id == excludingDocumentId) continue;
      final existing = DistrictModel.fromFirestore(document);
      final canonical =
          NepalDistrictDirectory.byId(document.id) ??
          NepalDistrictDirectory.byName(existing.name);
      if (canonical?.id == district.id) return true;
    }
    return false;
  }

  @override
  Future<void> create(DistrictModel district) async {
    final reference = _districts.doc(district.id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        final canonical = NepalDistrictDirectory.byId(district.id);
        throw DistrictDuplicateException(canonical?.name ?? district.name);
      }
      transaction.set(reference, district.toFirestore());
    });
  }

  @override
  Future<void> update(DistrictModel district) async {
    final reference = _districts.doc(district.id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) throw DistrictNotFoundException(district.id);
      transaction.update(reference, district.toFirestore());
    });
  }

  @override
  Future<void> delete(String id) async {
    final reference = _districts.doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) throw DistrictNotFoundException(id);
      transaction.delete(reference);
    });
  }
}

class DistrictService implements DistrictMutationService {
  DistrictService({DistrictRepository? repository})
    : _repository = repository ?? FirestoreDistrictRepository();

  final DistrictRepository _repository;

  Stream<List<DistrictModel>> getDistricts() async* {
    try {
      await for (final districts in _repository.watchAll()) {
        yield districts;
      }
    } on DistrictServiceException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _friendlyFirestoreError(error, 'read'),
        stackTrace,
      );
    }
  }

  Future<DistrictModel?> getDistrict(String id) {
    if (id.trim().isEmpty) {
      throw const DistrictValidationException('District ID is required.');
    }
    return _runFirestoreOperation('read', () => _repository.getById(id));
  }

  @override
  Future<void> addDistrict(DistrictModel district) async {
    final normalized = DistrictDataValidator.normalize(
      district,
      isCreate: true,
    );
    final canonical = NepalDistrictDirectory.byId(normalized.id)!;

    await _runFirestoreOperation('create', () async {
      if (await _repository.containsDistrict(canonical)) {
        throw DistrictDuplicateException(canonical.name);
      }
      await _repository.create(normalized);
    });
  }

  @override
  Future<void> updateDistrict(DistrictModel district) async {
    final normalized = DistrictDataValidator.normalize(
      district,
      isCreate: false,
    );
    final canonical = NepalDistrictDirectory.byName(normalized.name)!;

    await _runFirestoreOperation('update', () async {
      final existing = await _repository.getById(normalized.id);
      if (existing == null) throw DistrictNotFoundException(normalized.id);
      final existingCanonical = NepalDistrictDirectory.byId(existing.id);
      if (existingCanonical == null) {
        throw DistrictLegacyRecordException(canonical.name);
      }
      if (existing.name != existingCanonical.name ||
          existing.province != existingCanonical.province) {
        throw const DistrictValidationException(
          'The existing district name or province does not match its document '
          'ID. No changes were made.',
        );
      }
      if (existingCanonical.id != canonical.id) {
        throw const DistrictValidationException(
          'A district record’s canonical identity cannot be changed. No '
          'changes were made.',
        );
      }
      if (await _repository.containsDistrict(
        canonical,
        excludingDocumentId: normalized.id,
      )) {
        throw DistrictDuplicateException(canonical.name);
      }
      await _repository.update(normalized);
    });
  }

  @override
  Future<void> deleteDistrict(String id) {
    if (id.trim().isEmpty) {
      throw const DistrictValidationException('District ID is required.');
    }
    return _runFirestoreOperation('delete', () async {
      final existing = await _repository.getById(id);
      if (existing == null) throw DistrictNotFoundException(id);

      final canonical = NepalDistrictDirectory.byId(id);
      if (canonical == null) {
        throw DistrictLegacyRecordException(existing.name);
      }
      if (existing.name != canonical.name ||
          existing.province != canonical.province) {
        throw const DistrictValidationException(
          'The existing district name or province does not match its '
          'canonical document ID. No changes were made.',
        );
      }
      DistrictDataValidator.normalize(existing, isCreate: false);
      if (existing.updatedAt == null) {
        throw const DistrictValidationException(
          'The existing district record has no valid updated date. No '
          'changes were made.',
        );
      }

      await _repository.delete(id);
    });
  }

  Future<T> _runFirestoreOperation<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on DistrictServiceException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _friendlyFirestoreError(error, operation),
        stackTrace,
      );
    }
  }

  DistrictServiceException _friendlyFirestoreError(
    FirebaseException error,
    String operation,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return DistrictServiceException(
          'You do not have permission to $operation district data. Admin '
          'authorization may be required.',
        );
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return DistrictServiceException(
          'Could not connect to Firestore to $operation district data. '
          'Check your internet connection and try again.',
        );
      case 'not-found':
        return const DistrictServiceException(
          'The requested district record could not be found.',
        );
      default:
        return DistrictServiceException(
          'Could not $operation district data. Please try again.',
        );
    }
  }
}

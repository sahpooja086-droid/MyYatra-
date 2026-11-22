import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/nepal_district_directory.dart';
import '../models/district_model.dart';
import '../models/place_model.dart';
import 'place_data_validator.dart';

abstract interface class PlaceRepository {
  Stream<List<PlaceModel>> watchAll();

  Future<PlaceModel?> getById(String id);

  Future<DistrictModel?> getDistrictById(String id);

  Future<void> create(PlaceModel place);

  Future<void> update(PlaceModel place);

  Future<void> delete(String id);
}

class PlaceServiceException implements Exception {
  const PlaceServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaceDuplicateException extends PlaceServiceException {
  const PlaceDuplicateException(String name)
    : super(
        '$name already exists in this district. Existing data was not changed.',
      );
}

class PlaceNotFoundException extends PlaceServiceException {
  const PlaceNotFoundException(String id) : super('Place "$id" was not found.');
}

class PlaceLegacyRecordException extends PlaceServiceException {
  const PlaceLegacyRecordException(String name)
    : super(
        '$name is malformed or has a non-canonical ID or district reference. '
        'An administrator must review it before it can be changed.',
      );
}

class FirestorePlaceRepository implements PlaceRepository {
  FirestorePlaceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _places =>
      _firestore.collection('places');

  CollectionReference<Map<String, dynamic>> get _districts =>
      _firestore.collection('districts');

  CollectionReference<Map<String, dynamic>> get _districtPlaceCounts =>
      _firestore.collection('districtPlaceCounts');

  @override
  Stream<List<PlaceModel>> watchAll() {
    return _places.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(PlaceModel.fromFirestore).toList(growable: false),
    );
  }

  @override
  Future<PlaceModel?> getById(String id) async {
    final snapshot = await _places.doc(id).get();
    if (!snapshot.exists) return null;
    return PlaceModel.fromFirestore(snapshot);
  }

  @override
  Future<DistrictModel?> getDistrictById(String id) async {
    final snapshot = await _districts.doc(id).get();
    if (!snapshot.exists) return null;
    return DistrictModel.fromFirestore(snapshot);
  }

  @override
  Future<void> create(PlaceModel place) async {
    final placeReference = _places.doc(place.id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(placeReference);
      if (existing.exists) throw PlaceDuplicateException(place.name);
      await _changeDistrictPlaceCount(transaction, place, 1);
      transaction.set(placeReference, place.toFirestore());
    });
  }

  @override
  Future<void> update(PlaceModel place) async {
    final reference = _places.doc(place.id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) throw PlaceNotFoundException(place.id);
      final current = PlaceModel.fromFirestore(existing);
      if (current.id != place.id ||
          current.name != place.name ||
          current.districtId != place.districtId) {
        throw const PlaceServiceException(
          'A place name, district, and canonical ID cannot be changed during '
          'an update.',
        );
      }
      final data = place.toFirestore();
      if (place.imageUrl == null) data['imageUrl'] = FieldValue.delete();
      transaction.update(reference, data);
    });
  }

  @override
  Future<void> delete(String id) async {
    final reference = _places.doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) throw PlaceNotFoundException(id);
      await _changeDistrictPlaceCount(
        transaction,
        PlaceModel.fromFirestore(existing),
        -1,
      );
      transaction.delete(reference);
    });
  }

  Future<void> _changeDistrictPlaceCount(
    Transaction transaction,
    PlaceModel place,
    int delta,
  ) async {
    final index = await transaction.get(
      _firestore.doc('internal/placeReferenceIndex'),
    );
    final reference = _districtPlaceCounts.doc(place.districtId);
    final current = await transaction.get(reference);
    final count = current.exists ? current.data()!['count'] : 0;
    if (!index.exists || count is! int || count < 0 || count + delta < 0) {
      throw const PlaceServiceException(
        'Place references need verification before a place can be added or '
        'deleted. No changes were made.',
      );
    }
    transaction.set(reference, {'count': count + delta, 'placeId': place.id});
  }
}

/// Firebase rules remain the authoritative write boundary.
class PlaceService {
  PlaceService({
    PlaceRepository? repository,
    this._beforeMutation,
  }) : _repository = repository ?? FirestorePlaceRepository();

  final PlaceRepository _repository;
  final Future<void> Function()? _beforeMutation;

  Stream<List<PlaceModel>> getPlaces() async* {
    try {
      await for (final places in _repository.watchAll()) {
        yield places;
      }
    } on PlaceServiceException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(_friendlyError(error, 'read'), stackTrace);
    }
  }

  Future<PlaceModel?> getPlace(String id) {
    if (id.trim().isEmpty) {
      throw const PlaceValidationException('Place ID is required.');
    }
    return _run('read', () => _repository.getById(id));
  }

  Future<void> addPlace(PlaceModel place) async {
    await _beforeMutation?.call();
    final normalized = PlaceDataValidator.normalize(
      place,
      districts: await _validatedDistrict(place.districtId),
      isCreate: true,
    );
    await _run('create', () => _repository.create(normalized));
  }

  Future<void> updatePlace(PlaceModel place) async {
    await _beforeMutation?.call();
    final existing = await _run('read', () => _repository.getById(place.id));
    if (existing == null) throw PlaceNotFoundException(place.id);
    if (existing.name != place.name.trim() ||
        existing.districtId != place.districtId.trim()) {
      throw const PlaceValidationException(
        'A place name and district cannot be changed after creation. Create a '
        'new place record to use a different identity.',
      );
    }
    final districts = await _validatedDistrict(existing.districtId);
    _validateStoredIdentity(existing, districts);
    final normalized = PlaceDataValidator.normalize(
      place,
      districts: districts,
      isCreate: false,
    );
    await _run('update', () => _repository.update(normalized));
  }

  Future<void> deletePlace(String id) async {
    await _beforeMutation?.call();
    final existing = await _run('read', () => _repository.getById(id));
    if (existing == null) throw PlaceNotFoundException(id);
    final districts = await _validatedDistrict(existing.districtId);
    _validateStoredIdentity(existing, districts);
    PlaceDataValidator.normalize(
      existing,
      districts: districts,
      isCreate: false,
    );
    await _run('delete', () => _repository.delete(id));
  }

  Future<List<DistrictModel>> _validatedDistrict(String districtId) async {
    if (districtId.trim().isEmpty) {
      throw const PlaceValidationException('Select a district.');
    }
    final district = await _run(
      'read district reference',
      () => _repository.getDistrictById(districtId),
    );
    final canonical = NepalDistrictDirectory.byId(districtId);
    if (district == null ||
        canonical == null ||
        district.id != canonical.id ||
        district.name.trim() != canonical.name ||
        district.province.trim() != canonical.province) {
      throw const PlaceValidationException(
        'Select an existing canonical district. The district reference is '
        'missing or needs administrator review.',
      );
    }
    return [district];
  }

  void _validateStoredIdentity(
    PlaceModel place,
    List<DistrictModel> districts,
  ) {
    try {
      if (place.updatedAt == null) {
        throw const PlaceValidationException(
          'Existing place record has no valid updated date.',
        );
      }
      PlaceDataValidator.normalize(
        place,
        districts: districts,
        isCreate: false,
      );
    } on PlaceValidationException {
      throw PlaceLegacyRecordException(
        place.name.isEmpty ? place.id : place.name,
      );
    }
  }

  Future<T> _run<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on PlaceServiceException {
      rethrow;
    } on PlaceValidationException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(_friendlyError(error, operation), stackTrace);
    }
  }

  PlaceServiceException _friendlyError(
    FirebaseException error,
    String operation,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return PlaceServiceException(
          'You do not have permission to $operation place data. Admin '
          'authorization may be required.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return PlaceServiceException(
          'Could not connect to Firestore to $operation place data. Check the '
          'connection and try again.',
        );
      case 'not-found':
        return const PlaceServiceException(
          'The requested place or district reference could not be found.',
        );
      default:
        return PlaceServiceException(
          'Could not $operation place data. Please try again.',
        );
    }
  }
}

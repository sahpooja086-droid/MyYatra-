import '../models/district_model.dart';

/// Write-only contract consumed by district management.
///
/// The production screen does not receive a Firestore-backed implementation
/// until live writes are explicitly enabled in a later approved stage.
abstract interface class DistrictMutationService {
  Future<void> addDistrict(DistrictModel district);

  Future<void> updateDistrict(DistrictModel district);

  Future<void> deleteDistrict(String id);
}

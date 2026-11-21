import 'package:myyatra/data/nepal_district_directory.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/services/district_data_validator.dart';
import 'package:myyatra/services/district_mutation_service.dart';
import 'package:myyatra/services/district_service.dart';

class FakeDistrictMutationService implements DistrictMutationService {
  FakeDistrictMutationService([Iterable<DistrictModel> initial = const []]) {
    for (final district in initial) {
      districts[district.id] = district;
    }
  }

  final Map<String, DistrictModel> districts = {};
  Object? operationError;
  Future<void> Function()? beforeOperation;
  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  Future<void> _prepareOperation() async {
    await beforeOperation?.call();
    final error = operationError;
    if (error != null) throw error;
  }

  @override
  Future<void> addDistrict(DistrictModel district) async {
    await _prepareOperation();
    final normalized = DistrictDataValidator.normalize(
      district,
      isCreate: true,
    );
    final canonical = NepalDistrictDirectory.byId(normalized.id)!;
    if (_containsCanonicalDistrict(canonical.id)) {
      throw DistrictDuplicateException(canonical.name);
    }
    addCalls++;
    districts[normalized.id] = normalized;
  }

  @override
  Future<void> updateDistrict(DistrictModel district) async {
    await _prepareOperation();
    final normalized = DistrictDataValidator.normalize(
      district,
      isCreate: false,
    );
    final existing = districts[normalized.id];
    if (existing == null) throw DistrictNotFoundException(normalized.id);
    final canonicalExisting = NepalDistrictDirectory.byId(existing.id);
    if (canonicalExisting == null) {
      throw DistrictLegacyRecordException(normalized.name);
    }
    if (existing.name != canonicalExisting.name ||
        existing.province != canonicalExisting.province ||
        canonicalExisting.id !=
            NepalDistrictDirectory.byName(normalized.name)!.id) {
      throw const DistrictValidationException(
        'The district identity cannot be changed.',
      );
    }
    if (_containsCanonicalDistrict(
      canonicalExisting.id,
      excludingId: existing.id,
    )) {
      throw DistrictDuplicateException(canonicalExisting.name);
    }
    updateCalls++;
    districts[normalized.id] = normalized;
  }

  @override
  Future<void> deleteDistrict(String id) async {
    await _prepareOperation();
    if (NepalDistrictDirectory.byId(id) == null) {
      throw const DistrictValidationException(
        'Only canonical district records can be deleted from this screen.',
      );
    }
    if (!districts.containsKey(id)) throw DistrictNotFoundException(id);
    deleteCalls++;
    districts.remove(id);
  }

  bool _containsCanonicalDistrict(String canonicalId, {String? excludingId}) {
    for (final entry in districts.entries) {
      if (entry.key == excludingId) continue;
      final existing =
          NepalDistrictDirectory.byId(entry.key) ??
          NepalDistrictDirectory.byName(entry.value.name);
      if (existing?.id == canonicalId) return true;
    }
    return false;
  }
}

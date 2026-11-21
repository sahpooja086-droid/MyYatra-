import '../data/nepal_district_directory.dart';
import '../models/district_model.dart';

class DistrictValidationException implements Exception {
  const DistrictValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DistrictDataValidator {
  DistrictDataValidator._();

  static const int maxDescriptionLength = 2000;

  /// Validates and normalizes fields while preserving an existing document ID.
  /// New records must use the canonical stable ID for the selected district.
  static DistrictModel normalize(
    DistrictModel district, {
    required bool isCreate,
  }) {
    if (district.id.trim().isEmpty) {
      throw const DistrictValidationException('District ID is required.');
    }

    final canonical = NepalDistrictDirectory.byName(district.name.trim());
    if (canonical == null) {
      throw const DistrictValidationException(
        'Select a district from Nepal’s canonical list of 77 districts.',
      );
    }
    if (!isCreate && district.name.trim() != canonical.name) {
      throw DistrictValidationException(
        'Use the canonical district name “${canonical.name}” before updating.',
      );
    }

    final province = district.province.trim();
    if (province.isEmpty) {
      throw const DistrictValidationException('Province is required.');
    }
    if (province.toLowerCase() != canonical.province.toLowerCase()) {
      throw DistrictValidationException(
        '${canonical.name} belongs to ${canonical.province}, not $province.',
      );
    }

    final description = district.description.trim();
    if (description.isEmpty) {
      throw const DistrictValidationException('Description is required.');
    }
    if (description.length > maxDescriptionLength) {
      throw const DistrictValidationException(
        'Description must be 2000 characters or fewer.',
      );
    }

    if (district.experienceTypes.isEmpty) {
      throw const DistrictValidationException(
        'Select at least one experience type.',
      );
    }
    final experienceTypes = district.experienceTypes
        .map((type) => type.trim())
        .toList(growable: false);
    final unsupported = experienceTypes.where(
      (type) => !NepalDistrictDirectory.experienceCategories.contains(type),
    );
    if (unsupported.isNotEmpty) {
      throw DistrictValidationException(
        'Unsupported experience type: ${unsupported.first}.',
      );
    }
    if (experienceTypes.toSet().length != experienceTypes.length) {
      throw const DistrictValidationException(
        'Remove duplicate experience types.',
      );
    }

    if (isCreate && district.id != canonical.id) {
      throw DistrictValidationException(
        'The district ID must be the canonical ID “${canonical.id}”.',
      );
    }

    return DistrictModel(
      id: district.id,
      name: canonical.name,
      province: canonical.province,
      description: description,
      experienceTypes: experienceTypes,
      updatedAt: district.updatedAt,
    );
  }
}

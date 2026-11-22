import '../data/nepal_district_directory.dart';
import '../models/district_model.dart';
import '../models/place_model.dart';

class PlaceValidationException implements Exception {
  const PlaceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaceDataValidator {
  PlaceDataValidator._();

  static const int maxNameLength = 120;
  static const int maxCategoryLength = 80;
  static const int maxDescriptionLength = 2000;
  static const int maxImageUrlLength = 2048;

  static String canonicalId(String name, String districtId) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$districtId--$slug';
  }

  static PlaceModel normalize(
    PlaceModel place, {
    required List<DistrictModel> districts,
    required bool isCreate,
  }) {
    final name = place.name.trim();
    if (name.isEmpty) {
      throw const PlaceValidationException('Place name is required.');
    }
    if (name.length > maxNameLength) {
      throw const PlaceValidationException(
        'Place name must be 120 characters or fewer.',
      );
    }
    if (canonicalId(name, place.districtId.trim()).endsWith('--')) {
      throw const PlaceValidationException(
        'Place name must include at least one English letter or number.',
      );
    }

    final category = place.category.trim();
    if (category.isEmpty) {
      throw const PlaceValidationException('Category is required.');
    }
    if (category.length > maxCategoryLength) {
      throw const PlaceValidationException(
        'Category must be 80 characters or fewer.',
      );
    }

    final districtId = place.districtId.trim();
    final canonicalDistrict = NepalDistrictDirectory.byId(districtId);
    DistrictModel? selectedDistrict;
    for (final district in districts) {
      if (district.id == districtId) {
        selectedDistrict = district;
        break;
      }
    }
    if (districtId.isEmpty) {
      throw const PlaceValidationException('Select a district.');
    }
    if (canonicalDistrict == null ||
        selectedDistrict == null ||
        selectedDistrict.name.trim() != canonicalDistrict.name ||
        selectedDistrict.province.trim() != canonicalDistrict.province) {
      throw const PlaceValidationException(
        'Select a supported district from the district list.',
      );
    }

    final description = place.description.trim();
    if (description.isEmpty) {
      throw const PlaceValidationException('Description is required.');
    }
    if (description.length > maxDescriptionLength) {
      throw const PlaceValidationException(
        'Description must be 2000 characters or fewer.',
      );
    }

    final imageUrl = place.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final parsedUrl = Uri.tryParse(imageUrl);
      if (imageUrl.length > maxImageUrlLength ||
          parsedUrl == null ||
          parsedUrl.scheme != 'https' ||
          parsedUrl.host.isEmpty) {
        throw const PlaceValidationException(
          'Image URL must be a valid HTTPS address of 2048 characters or fewer.',
        );
      }
    }

    final canonicalPlaceId = canonicalId(name, districtId);
    if (isCreate && place.id.isNotEmpty && place.id != canonicalPlaceId) {
      throw PlaceValidationException(
        'Place ID must use its canonical value: $canonicalPlaceId.',
      );
    }
    if (!isCreate && place.id != canonicalPlaceId) {
      throw const PlaceValidationException(
        'Place name and district must match the existing canonical place ID.',
      );
    }

    return PlaceModel(
      id: isCreate ? canonicalPlaceId : place.id,
      name: name,
      category: category,
      districtId: districtId,
      description: description,
      imageUrl: imageUrl == null || imageUrl.isEmpty ? null : imageUrl,
      updatedAt: place.updatedAt,
    );
  }
}

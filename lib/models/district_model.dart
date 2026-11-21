
import 'package:cloud_firestore/cloud_firestore.dart';

class DistrictModel {
  final String id;
  final String name;
  final String province;
  final String description;
  final List<String> experienceTypes;
  final DateTime? updatedAt;

  DistrictModel({
    required this.id,
    required this.name,
    required this.province,
    required this.description,
    required this.experienceTypes,
    this.updatedAt,
  });

  factory DistrictModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    return DistrictModel.fromMap(document.id, document.data());
  }

  factory DistrictModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    final rawExperienceTypes = values['experienceTypes'];
    final rawUpdatedAt = values['updatedAt'];

    return DistrictModel(
      id: id,
      name: values['name'] is String ? values['name'] as String : '',
      province: values['province'] is String
          ? values['province'] as String
          : '',
      description: values['description'] is String
          ? values['description'] as String
          : '',
      experienceTypes: rawExperienceTypes is List
          ? rawExperienceTypes.whereType<String>().toList()
          : const [],
      updatedAt: switch (rawUpdatedAt) {
        Timestamp timestamp => timestamp.toDate(),
        DateTime dateTime => dateTime,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'province': province,
      'description': description,
      'experienceTypes': experienceTypes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

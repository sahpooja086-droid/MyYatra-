import 'package:cloud_firestore/cloud_firestore.dart';

/// A tourist place associated with a district.
class PlaceModel {
  const PlaceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.districtId,
    required this.description,
    this.imageUrl,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String districtId;
  final String description;
  final String? imageUrl;
  final DateTime? updatedAt;

  factory PlaceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return PlaceModel.fromMap(document.id, document.data());
  }

  factory PlaceModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    final rawUpdatedAt = values['updatedAt'];
    return PlaceModel(
      id: id,
      name: values['name'] is String ? values['name'] as String : '',
      category: values['category'] is String
          ? values['category'] as String
          : '',
      districtId: values['districtId'] is String
          ? values['districtId'] as String
          : '',
      description: values['description'] is String
          ? values['description'] as String
          : '',
      imageUrl: values['imageUrl'] is String
          ? values['imageUrl'] as String
          : null,
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
      'category': category,
      'districtId': districtId,
      'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

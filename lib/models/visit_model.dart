import 'package:cloud_firestore/cloud_firestore.dart';

/// A private record of a place the signed-in user has visited.
class VisitModel {
  const VisitModel({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.districtId,
    required this.visitedAt,
    required this.notes,
    required this.rating,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String placeId;
  final String placeName;
  final String districtId;
  final DateTime visitedAt;
  final String notes;
  final int rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VisitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return VisitModel.fromMap(document.id, document.data());
  }

  factory VisitModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    return VisitModel(
      id: id,
      placeId: values['placeId'] is String ? values['placeId'] as String : '',
      placeName: values['placeName'] is String
          ? values['placeName'] as String
          : '',
      districtId: values['districtId'] is String
          ? values['districtId'] as String
          : '',
      visitedAt: _asDate(values['visitedAt']) ?? DateTime.now(),
      notes: values['notes'] is String ? values['notes'] as String : '',
      rating: values['rating'] is int ? values['rating'] as int : 3,
      createdAt: _asDate(values['createdAt']),
      updatedAt: _asDate(values['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'districtId': districtId,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'notes': notes,
      'rating': rating,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

DateTime? _asDate(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => null,
  };
}

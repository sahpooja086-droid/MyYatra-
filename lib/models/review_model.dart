import 'package:cloud_firestore/cloud_firestore.dart';

/// A public review. Only [displayName] is ever shown to other readers; the
/// owner UID is retained solely so Firestore rules can verify authorship.
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.ownerUid,
    required this.displayName,
    required this.targetType,
    required this.targetId,
    required this.rating,
    required this.text,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String displayName;
  final String targetType;
  final String targetId;
  final int rating;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String placeTarget = 'place';
  static const String districtTarget = 'district';

  factory ReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ReviewModel.fromMap(document.id, document.data());
  }

  factory ReviewModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    return ReviewModel(
      id: id,
      ownerUid: values['ownerUid'] is String
          ? values['ownerUid'] as String
          : '',
      displayName: values['displayName'] is String
          ? values['displayName'] as String
          : '',
      targetType: values['targetType'] is String
          ? values['targetType'] as String
          : placeTarget,
      targetId: values['targetId'] is String
          ? values['targetId'] as String
          : '',
      rating: values['rating'] is int ? values['rating'] as int : 3,
      text: values['text'] is String ? values['text'] as String : '',
      createdAt: _asDate(values['createdAt']),
      updatedAt: _asDate(values['updatedAt']),
    );
  }

  /// Deterministic ID so one user can leave at most one review per target.
  static String documentIdFor({
    required String ownerUid,
    required String targetType,
    required String targetId,
  }) {
    return '$ownerUid--$targetType--$targetId';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'displayName': displayName,
      'targetType': targetType,
      'targetId': targetId,
      'rating': rating,
      'text': text,
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

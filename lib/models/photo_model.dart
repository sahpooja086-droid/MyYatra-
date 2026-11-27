import 'package:cloud_firestore/cloud_firestore.dart';

/// Privacy-preserving metadata for a photo uploaded by the signed-in user.
///
/// The image itself lives in Firebase Storage under the same owner-only path.
class PhotoModel {
  const PhotoModel({
    required this.id,
    required this.downloadUrl,
    required this.storagePath,
    required this.caption,
    required this.placeId,
    required this.districtId,
    required this.capturedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String downloadUrl;
  final String storagePath;
  final String caption;
  final String placeId;
  final String districtId;
  final DateTime capturedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PhotoModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return PhotoModel.fromMap(document.id, document.data());
  }

  factory PhotoModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    return PhotoModel(
      id: id,
      downloadUrl: values['downloadUrl'] is String
          ? values['downloadUrl'] as String
          : '',
      storagePath: values['storagePath'] is String
          ? values['storagePath'] as String
          : '',
      caption: values['caption'] is String ? values['caption'] as String : '',
      placeId: values['placeId'] is String ? values['placeId'] as String : '',
      districtId: values['districtId'] is String
          ? values['districtId'] as String
          : '',
      capturedAt: _asDate(values['capturedAt']) ?? DateTime.now(),
      createdAt: _asDate(values['createdAt']),
      updatedAt: _asDate(values['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'caption': caption,
      'placeId': placeId,
      'districtId': districtId,
      'capturedAt': Timestamp.fromDate(capturedAt),
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

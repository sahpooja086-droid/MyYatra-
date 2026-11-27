import 'package:cloud_firestore/cloud_firestore.dart';

/// A private journal entry written by the signed-in user.
class JournalEntryModel {
  const JournalEntryModel({
    required this.id,
    required this.title,
    required this.body,
    required this.placeId,
    required this.districtId,
    required this.entryDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String placeId;
  final String districtId;
  final DateTime entryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory JournalEntryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return JournalEntryModel.fromMap(document.id, document.data());
  }

  factory JournalEntryModel.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    return JournalEntryModel(
      id: id,
      title: values['title'] is String ? values['title'] as String : '',
      body: values['body'] is String ? values['body'] as String : '',
      placeId: values['placeId'] is String ? values['placeId'] as String : '',
      districtId: values['districtId'] is String
          ? values['districtId'] as String
          : '',
      entryDate: _asDate(values['entryDate']) ?? DateTime.now(),
      createdAt: _asDate(values['createdAt']),
      updatedAt: _asDate(values['updatedAt']),
    );
  }

  JournalEntryModel copyWith({
    String? title,
    String? body,
    String? placeId,
    String? districtId,
    DateTime? entryDate,
  }) {
    return JournalEntryModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      placeId: placeId ?? this.placeId,
      districtId: districtId ?? this.districtId,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'placeId': placeId,
      'districtId': districtId,
      'entryDate': Timestamp.fromDate(entryDate),
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

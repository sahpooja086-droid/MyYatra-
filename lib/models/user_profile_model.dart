import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's private account profile.
class UserProfileModel {
  const UserProfileModel({
    required this.uid,
    required this.fullName,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String fullName;
  final String displayName;
  final String email;

  factory UserProfileModel.fromMap(String uid, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    final fullName = values['fullName'] is String
        ? values['fullName'] as String
        : '';
    final displayName = values['displayName'] is String
        ? values['displayName'] as String
        : fullName;
    return UserProfileModel(
      uid: uid,
      fullName: fullName,
      displayName: displayName.trim().isEmpty ? 'MyYatra traveller' : displayName,
      email: values['email'] is String ? values['email'] as String : '',
    );
  }

  factory UserProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return UserProfileModel.fromMap(document.id, document.data());
  }
}

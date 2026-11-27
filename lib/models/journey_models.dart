import 'package:cloud_firestore/cloud_firestore.dart';

/// Derived travel preferences computed from the user's own data.
class JourneyDnaModel {
  const JourneyDnaModel({
    required this.traits,
    required this.summary,
    this.updatedAt,
  });

  final List<String> traits;
  final String summary;
  final DateTime? updatedAt;

  factory JourneyDnaModel.fromMap(Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    final rawTraits = values['traits'];
    return JourneyDnaModel(
      traits: rawTraits is List
          ? rawTraits.whereType<String>().toList(growable: false)
          : const [],
      summary: values['summary'] is String ? values['summary'] as String : '',
      updatedAt: switch (values['updatedAt']) {
        Timestamp timestamp => timestamp.toDate(),
        DateTime dateTime => dateTime,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'traits': traits,
      'summary': summary,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Difference between the user's travel goals and their recorded visits.
class GapAnalysisModel {
  const GapAnalysisModel({
    required this.visitedDistricts,
    required this.targetDistricts,
    required this.unvisitedDistricts,
    required this.missingExperienceTypes,
    required this.coveragePercent,
  });

  final int visitedDistricts;
  final int targetDistricts;
  final List<String> unvisitedDistricts;
  final List<String> missingExperienceTypes;
  final int coveragePercent;
}

/// A ranked suggestion derived from Journey DNA and the gap analysis.
class RecommendationModel {
  const RecommendationModel({
    required this.title,
    required this.reason,
    required this.districtId,
    required this.experienceType,
    this.placeId,
  });

  final String title;
  final String reason;
  final String districtId;
  final String experienceType;
  final String? placeId;
}

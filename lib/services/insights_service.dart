import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/data_use_inputs.dart';
import '../models/district_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journey_models.dart';
import '../models/photo_model.dart';
import '../models/place_model.dart';
import '../models/visit_model.dart';
import 'personal_travel_service.dart';

/// Everything derived from the user's own data, together in one snapshot.
class TravelInsights {
  const TravelInsights({
    required this.dna,
    required this.gapAnalysis,
    required this.recommendations,
  });

  final JourneyDnaModel dna;
  final GapAnalysisModel gapAnalysis;
  final List<RecommendationModel> recommendations;
}

/// Builds Journey DNA, gap analysis, and recommendations from private user
/// records plus public district/place information.
class TravelInsightsService {
  TravelInsightsService({
    PersonalTravelService? personal,
    FirebaseFirestore? firestore,
  }) : _personal = personal ?? PersonalTravelService(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final PersonalTravelService _personal;
  final FirebaseFirestore _firestore;

  Future<TravelInsights> build({bool saveDna = false}) async {
    final visits = await _personal.getVisitsOnce();
    final journal = await _personal.getJournalEntriesOnce();
    final photos = await _personal.getPhotosOnce();
    final districtsSnapshot = await _firestore.collection('districts').get();
    final placesSnapshot = await _firestore.collection('places').get();
    final districts = districtsSnapshot.docs
        .map(DistrictModel.fromFirestore)
        .toList(growable: false);
    final places = placesSnapshot.docs
        .map(PlaceModel.fromFirestore)
        .toList(growable: false);

    final insights = compute(
      visits: visits,
      journal: journal,
      photos: photos,
      districts: districts,
      places: places,
    );
    if (saveDna) {
      await _personal.saveJourneyDna(insights.dna);
    }
    return insights;
  }

  /// Pure computation, so behaviour can be tested without Firestore.
  static TravelInsights compute({
    required List<VisitModel> visits,
    required List<JournalEntryModel> journal,
    required List<PhotoModel> photos,
    required List<DistrictModel> districts,
    required List<PlaceModel> places,
  }) {
    final districtById = {
      for (final district in districts) district.id: district,
    };
    final scores = {for (final type in journeyExperienceTypes) type: 0};

    void addKeywordScores(String text, int weight) {
      final lower = text.toLowerCase();
      for (final entry in _keywords.entries) {
        for (final keyword in entry.value) {
          if (lower.contains(keyword)) {
            scores[entry.key] = scores[entry.key]! + weight;
          }
        }
      }
    }

    final visitedDistrictIds = <String>{};
    for (final visit in visits) {
      if (visit.districtId.isNotEmpty) visitedDistrictIds.add(visit.districtId);
      final district = districtById[visit.districtId];
      if (district != null) {
        for (final type in district.experienceTypes) {
          if (scores.containsKey(type)) {
            scores[type] = scores[type]! + 3;
          }
        }
      }
      if (visit.rating >= 4) {
        for (final type in district?.experienceTypes ?? const <String>[]) {
          if (scores.containsKey(type)) {
            scores[type] = scores[type]! + 1;
          }
        }
      }
      addKeywordScores('${visit.placeName} ${visit.notes}', 1);
    }

    for (final entry in journal) {
      if (entry.districtId.isNotEmpty) {
        visitedDistrictIds.add(entry.districtId);
      }
      addKeywordScores('${entry.title} ${entry.body}', 1);
    }

    for (final photo in photos) {
      if (photo.districtId.isNotEmpty) {
        visitedDistrictIds.add(photo.districtId);
      }
      addKeywordScores(photo.caption, 1);
    }

    final rankedTypes = journeyExperienceTypes
        .where((type) => scores[type]! > 0)
        .toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final traits = rankedTypes.take(3).toList(growable: false);

    final summary = _summaryFor(
      traits,
      visits.length,
      journal.length,
      photos.length,
    );
    final dna = JourneyDnaModel(traits: traits, summary: summary);

    final sortedDistricts = [...districts]
      ..sort((a, b) => a.name.compareTo(b.name));
    final unvisitedDistricts = sortedDistricts
        .where((district) => !visitedDistrictIds.contains(district.id))
        .map((district) => district.name)
        .toList(growable: false);
    final targetDistricts = sortedDistricts.length;
    final visitedDistricts = sortedDistricts
        .where((district) => visitedDistrictIds.contains(district.id))
        .length;
    final coveredTypes = <String>{
      for (final district in sortedDistricts)
        if (visitedDistrictIds.contains(district.id))
          ...district.experienceTypes,
    };
    final missingExperienceTypes = journeyExperienceTypes
        .where((type) => !coveredTypes.contains(type))
        .toList(growable: false);
    final coveragePercent = targetDistricts == 0
        ? 0
        : ((visitedDistricts / targetDistricts) * 100).round();

    final gap = GapAnalysisModel(
      visitedDistricts: visitedDistricts,
      targetDistricts: targetDistricts,
      unvisitedDistricts: unvisitedDistricts,
      missingExperienceTypes: missingExperienceTypes,
      coveragePercent: coveragePercent,
    );

    final recommendations = _recommendations(
      traits: traits,
      missingExperienceTypes: missingExperienceTypes,
      unvisited: sortedDistricts
          .where((district) => !visitedDistrictIds.contains(district.id))
          .toList(growable: false),
      places: places,
    );

    return TravelInsights(
      dna: dna,
      gapAnalysis: gap,
      recommendations: recommendations,
    );
  }

  static String _summaryFor(
    List<String> traits,
    int visitCount,
    int journalCount,
    int photoCount,
  ) {
    if (visitCount == 0 && journalCount == 0 && photoCount == 0) {
      return 'Add a visit, journal entry, or photo to start forming your '
          'Journey DNA.';
    }
    final focus = traits.isEmpty
        ? 'a broad mix of experiences'
        : _joinTraits(traits);
    return 'Your Journey DNA currently leans toward $focus, shaped by '
        '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}, '
        '$journalCount ${journalCount == 1 ? 'journal entry' : 'journal entries'}, '
        'and $photoCount ${photoCount == 1 ? 'photo' : 'photos'}.';
  }

  static String _joinTraits(List<String> traits) {
    if (traits.length == 1) return traits.single;
    if (traits.length == 2) return '${traits[0]} and ${traits[1]}';
    return '${traits.take(traits.length - 1).join(', ')}, and ${traits.last}';
  }

  static List<RecommendationModel> _recommendations({
    required List<String> traits,
    required List<String> missingExperienceTypes,
    required List<DistrictModel> unvisited,
    required List<PlaceModel> places,
  }) {
    final results = <RecommendationModel>[];
    for (final district in unvisited) {
      final matches = district.experienceTypes
          .where((type) => traits.contains(type))
          .toList();
      final type = matches.isNotEmpty
          ? matches.first
          : district.experienceTypes.isNotEmpty
          ? district.experienceTypes.first
          : 'Nature';
      final place = places
          .where((place) => place.districtId == district.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final reason = matches.isNotEmpty
          ? 'Matches your ${_joinTraits(matches)} side.'
          : missingExperienceTypes.contains(type)
          ? 'Adds the $type experiences missing from your journey.'
          : 'A new district to broaden your journey.';
      results.add(
        RecommendationModel(
          title: district.name,
          reason: reason,
          districtId: district.id,
          experienceType: type,
          placeId: place.isEmpty ? null : place.first.id,
        ),
      );
    }
    results.sort((a, b) {
      final aMatch = traits.contains(a.experienceType) ? 1 : 0;
      final bMatch = traits.contains(b.experienceType) ? 1 : 0;
      return bMatch.compareTo(aMatch);
    });
    return results.take(5).toList(growable: false);
  }

  static const Map<String, List<String>> _keywords = {
    'Nature': [
      'mountain', 'trek', 'trail', 'valley', 'lake', 'river', 'forest',
      'park', 'hill', 'waterfall', 'wildlife', 'sunrise', 'sunset', 'view',
    ],
    'Adventure': [
      'rafting', 'hike', 'hiking', 'zipline', 'bungee', 'paragliding',
      'climb', 'climbing', 'adventure', 'bike', 'kayak', 'camp', 'safari',
    ],
    'Culture': [
      'temple', 'monastery', 'festival', 'culture', 'local', 'tradition',
      'dance', 'music', 'ritual',
    ],
    'History': [
      'fort', 'palace', 'durbar', 'museum', 'heritage', 'ancient', 'history',
      'ruins',
    ],
    'Food': [
      'food', 'momo', 'dal', 'tea', 'cafe', 'market', 'cuisine', 'eat',
      'restaurant',
    ],
    'Photography': [
      'photo', 'photograph', 'camera', 'capture', 'shot', 'sunrise', 'sunset',
      'view', 'panorama',
    ],
  };
}

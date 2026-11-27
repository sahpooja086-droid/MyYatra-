import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myyatra/data/data_use_inputs.dart';
import 'package:myyatra/models/district_model.dart';
import 'package:myyatra/models/journal_entry_model.dart';
import 'package:myyatra/models/review_model.dart';
import 'package:myyatra/models/visit_model.dart';
import 'package:myyatra/screens/reviews/review_tile.dart';
import 'package:myyatra/screens/settings/data_use_screen.dart';
import 'package:myyatra/services/insights_service.dart';

void main() {
  group('Story 1: private records are scoped to the owner', () {
    test('insight inputs are assembled only from the owner-provided records',
        () {
      // The service has no API surface that accepts another user's ID; these
      // models represent data already fetched from users/{uid}.
      final insights = TravelInsightsService.compute(
        visits: [
          _visit(placeName: 'Sarangkot', districtId: 'kaski', rating: 5),
        ],
        journal: [
          JournalEntryModel(
            id: 'entry',
            title: 'Sunrise hike',
            body: 'A quiet mountain morning.',
            placeId: 'kaski--sarangkot',
            districtId: 'kaski',
            entryDate: DateTime(2026, 1, 2),
          ),
        ],
        photos: const [],
        districts: [
          _district(
            id: 'kaski',
            name: 'Kaski',
            experienceTypes: const ['Nature', 'Adventure'],
          ),
          _district(
            id: 'chitwan',
            name: 'Chitwan',
            experienceTypes: const ['Nature', 'Culture'],
          ),
        ],
        places: const [],
      );

      expect(insights.dna.traits, contains('Nature'));
      expect(insights.gapAnalysis.visitedDistricts, 1);
      expect(insights.gapAnalysis.targetDistricts, 2);
      expect(insights.gapAnalysis.coveragePercent, 50);
      expect(insights.gapAnalysis.unvisitedDistricts, ['Chitwan']);
    });
  });

  group('Story 3: reviews expose only the display name', () {
    testWidgets('a review tile never renders the owner UID or email',
        (tester) async {
      const review = ReviewModel(
        id: 'review',
        ownerUid: 'private-owner-uid',
        displayName: 'Pooja Traveler',
        targetType: ReviewModel.placeTarget,
        targetId: 'kaski--sarangkot',
        rating: 5,
        text: 'Beautiful sunrise viewpoint.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReviewTile(review: review)),
        ),
      );

      expect(find.text('Pooja Traveler'), findsOneWidget);
      expect(find.textContaining('private-owner-uid'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
      expect(find.text('Beautiful sunrise viewpoint.'), findsOneWidget);
    });

    test('review document IDs are deterministic and owner-scoped', () {
      final first = ReviewModel.documentIdFor(
        ownerUid: 'traveler-uid',
        targetType: ReviewModel.placeTarget,
        targetId: 'kaski--sarangkot',
      );
      final second = ReviewModel.documentIdFor(
        ownerUid: 'traveler-uid',
        targetType: ReviewModel.placeTarget,
        targetId: 'kaski--sarangkot',
      );
      expect(first, second);
      expect(first, startsWith('traveler-uid--place--'));
    });
  });

  group('Story 2: data-use page lists every input and purpose', () {
    testWidgets('the page names the inputs behind each insight', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DataUseScreen()));

      expect(find.text('How your data is used'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      for (final label in [
        'Visits',
        'Journal entries',
        'Photos',
        'District experience types',
        'Your reviews',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          300,
          scrollable: scrollable,
        );
        expect(find.text(label), findsOneWidget);
      }

      await tester.scrollUntilVisible(
        find.text('Derived results'),
        300,
        scrollable: scrollable,
      );
      expect(find.textContaining('Journey DNA'), findsWidgets);
      expect(find.textContaining('Gap analysis'), findsWidgets);
      expect(find.textContaining('Recommendations'), findsWidgets);
    });

    test('every purpose is covered by at least one declared input', () {
      for (final purpose in DataUsePurpose.values) {
        expect(
          dataUseInputs.any((input) => input.purposes.contains(purpose)),
          isTrue,
          reason: 'No input is declared for $purpose',
        );
      }
    });
  });
}

VisitModel _visit({
  required String placeName,
  required String districtId,
  required int rating,
}) {
  return VisitModel(
    id: 'visit',
    placeId: '$districtId--${placeName.toLowerCase()}',
    placeName: placeName,
    districtId: districtId,
    visitedAt: DateTime(2026, 1, 1),
    notes: 'A mountain sunrise hike.',
    rating: rating,
  );
}

DistrictModel _district({
  required String id,
  required String name,
  required List<String> experienceTypes,
}) {
  return DistrictModel(
    id: id,
    name: name,
    province: 'Gandaki',
    description: '$name travel information',
    experienceTypes: experienceTypes,
  );
}

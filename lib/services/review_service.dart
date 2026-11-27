import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review_model.dart';

class ReviewException implements Exception {
  const ReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Public reviews. The service never reads another user's profile: only the
/// display name captured when the review was posted is shown.
class ReviewService {
  ReviewService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const ReviewException('Please sign in to post a review.');
    }
    return uid;
  }

  Stream<List<ReviewModel>> watchReviewsForTarget({
    required String targetType,
    required String targetId,
  }) {
    return _reviews
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ReviewModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError(_mapError);
  }

  Stream<List<ReviewModel>> watchMyReviews() {
    return _reviews
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ReviewModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError(_mapError);
  }

  Future<String> currentDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ReviewException('Please sign in to post a review.');
    }
    final document = await _firestore.collection('users').doc(user.uid).get();
    final stored = document.data()?['displayName'];
    if (stored is String && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final authName = user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    return 'MyYatra traveller';
  }

  Future<void> submitReview({
    required String targetType,
    required String targetId,
    required int rating,
    required String text,
  }) {
    return _run(() async {
      if (rating < 1 || rating > 5) {
        throw const ReviewException('Choose a rating between 1 and 5.');
      }
      final body = text.trim();
      if (body.isEmpty) {
        throw const ReviewException('Write a few words before posting.');
      }
      final uid = _uid;
      final displayName = await currentDisplayName();
      final review = ReviewModel(
        id: ReviewModel.documentIdFor(
          ownerUid: uid,
          targetType: targetType,
          targetId: targetId,
        ),
        ownerUid: uid,
        displayName: displayName,
        targetType: targetType,
        targetId: targetId,
        rating: rating,
        text: body,
      );
      await _reviews.doc(review.id).set(review.toFirestore());
    });
  }

  Future<void> deleteReview(String reviewId) {
    return _run(() async {
      await _reviews.doc(reviewId).delete();
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ReviewException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReviewException(_messageFor(error));
    }
  }

  Never _mapError(Object error) {
    if (error is FirebaseException) {
      throw ReviewException(_messageFor(error));
    }
    throw error;
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Only the author can change this review.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Reviews could not be loaded. Check your connection.';
      default:
        return 'Reviews could not be loaded. Please try again.';
    }
  }
}

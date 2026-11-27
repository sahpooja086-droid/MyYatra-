import 'package:flutter/material.dart';

import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';
import 'review_tile.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key, this.service});

  final ReviewService? service;

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late final ReviewService _service = widget.service ?? ReviewService();

  Future<void> _delete(ReviewModel review) async {
    if (!await confirmDelete(context, 'this review')) return;
    try {
      await _service.deleteReview(review.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionScaffold(
      title: 'My reviews',
      body: StreamBuilder<List<ReviewModel>>(
        stream: _service.watchMyReviews(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snapshot.data!;
          if (reviews.isEmpty) {
            return const AppEmptyState(
              icon: Icons.reviews_outlined,
              title: 'No reviews yet',
              message: 'Open a place to share your first review.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    review.targetId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AuthPalette.mutedText,
                    ),
                  ),
                  ReviewTile(
                    review: review,
                    onDelete: () => _delete(review),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

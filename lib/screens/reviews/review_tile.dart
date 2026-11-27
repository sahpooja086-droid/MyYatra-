import 'package:flutter/material.dart';

import '../../models/review_model.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';

/// Renders a review using only its public fields.
///
/// [ReviewModel.ownerUid] is intentionally never displayed. Readers see the
/// display name that was captured when the review was posted.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.onDelete});

  final ReviewModel review;
  final VoidCallback? onDelete;

  String get _initials {
    final parts = review.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AuthPalette.purple,
              foregroundColor: Colors.white,
              child: Text(
                _initials,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AuthPalette.ink,
                          ),
                        ),
                      ),
                      _Stars(rating: review.rating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(review.text, style: const TextStyle(height: 1.35)),
                  const SizedBox(height: 6),
                  Text(
                    review.createdAt == null
                        ? ''
                        : formatDate(review.createdAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AuthPalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete review',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AuthPalette.mutedText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            size: 16,
            color: AuthPalette.maroon,
          ),
      ],
    );
  }
}

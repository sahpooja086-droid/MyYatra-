import 'package:flutter/material.dart';

import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';
import 'review_tile.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    this.service,
  });

  final String targetType;
  final String targetId;
  final String targetName;
  final ReviewService? service;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final ReviewService _service = widget.service ?? ReviewService();

  Future<void> _writeReview() async {
    final draft = await showDialog<({int rating, String text})>(
      context: context,
      builder: (_) => const _ReviewFormDialog(),
    );
    if (draft == null) return;
    try {
      await _service.submitReview(
        targetType: widget.targetType,
        targetId: widget.targetId,
        rating: draft.rating,
        text: draft.text,
      );
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
      title: widget.targetName,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4EDF8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCCBE6)),
            ),
            child: const Row(
              children: [
                Icon(Icons.public, color: AuthPalette.maroon, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reviews are public. Other readers see only your display '
                    'name, never your email address.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _writeReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Write a review'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ReviewModel>>(
              stream: _service.watchReviewsForTarget(
                targetType: widget.targetType,
                targetId: widget.targetId,
              ),
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
                    message: 'Be the first to share your experience.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      ReviewTile(review: reviews[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewFormDialog extends StatefulWidget {
  const _ReviewFormDialog();

  @override
  State<_ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends State<_ReviewFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      (rating: _rating, text: _textController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a review'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Rating'),
                  const SizedBox(width: 8),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(
                        i <= _rating ? Icons.star : Icons.star_border,
                        color: AuthPalette.maroon,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(labelText: 'Your review'),
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Write a few words before posting'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Post')),
      ],
    );
  }
}

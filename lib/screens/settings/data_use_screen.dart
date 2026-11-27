import 'package:flutter/material.dart';

import '../../data/data_use_inputs.dart';
import '../auth/auth_widgets.dart';

class DataUseScreen extends StatelessWidget {
  const DataUseScreen({super.key});

  static const Map<DataUsePurpose, String> _purposeLabels = {
    DataUsePurpose.journeyDna: 'Journey DNA',
    DataUsePurpose.gapAnalysis: 'Gap analysis',
    DataUsePurpose.recommendations: 'Recommendations',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      appBar: AppBar(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        title: const Text('How your data is used'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'MyYatra uses only the inputs below to build your Journey '
                  'DNA, gap analysis, and recommendations. Private records '
                  'stay inside your account; the only public items are your '
                  'reviews, and those show your display name only.',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Inputs used',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (final input in dataUseInputs) ...[
              _InputCard(
                input: input,
                purposeLabels: _purposeLabels,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const Text(
              'Derived results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 10),
            const _DerivedCard(
              title: 'Journey DNA',
              body:
                  'A short profile of the experience types you lean toward. '
                  'It is calculated from your private records and the public '
                  'experience types of districts you have visited.',
            ),
            const SizedBox(height: 10),
            const _DerivedCard(
              title: 'Gap analysis',
              body:
                  'Compares the districts you have visited with all published '
                  'districts and highlights experience types you have not '
                  'covered yet.',
            ),
            const SizedBox(height: 10),
            const _DerivedCard(
              title: 'Recommendations',
              body:
                  'Suggests unvisited districts that match your Journey DNA or '
                  'fill a gap. Suggestions are shown only to you.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.input, required this.purposeLabels});

  final DataUseInput input;
  final Map<DataUsePurpose, String> purposeLabels;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    input.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.ink,
                    ),
                  ),
                ),
                _VisibilityChip(isPrivate: input.isPrivate),
              ],
            ),
            const SizedBox(height: 6),
            Text(input.description, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final purpose in input.purposes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EDF8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCCBE6)),
                    ),
                    child: Text(
                      purposeLabels[purpose] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AuthPalette.maroon,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrivate
            ? const Color(0xFFEAF4EC)
            : const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_outline : Icons.public,
            size: 13,
            color: isPrivate ? const Color(0xFF2E6B3A) : const Color(0xFF8A5A00),
          ),
          const SizedBox(width: 4),
          Text(
            isPrivate ? 'Private' : 'Public',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPrivate
                  ? const Color(0xFF2E6B3A)
                  : const Color(0xFF8A5A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _DerivedCard extends StatelessWidget {
  const _DerivedCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: AuthPalette.purple),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(body),
      ),
    );
  }
}

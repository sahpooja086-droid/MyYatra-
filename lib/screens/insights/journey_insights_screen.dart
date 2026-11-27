import 'package:flutter/material.dart';

import '../../models/journey_models.dart';
import '../../services/insights_service.dart';
import '../auth/auth_widgets.dart';
import '../common/app_ui.dart';

class JourneyInsightsScreen extends StatefulWidget {
  const JourneyInsightsScreen({
    super.key,
    this.initialIndex = 0,
    this.service,
  });

  final int initialIndex;
  final TravelInsightsService? service;

  @override
  State<JourneyInsightsScreen> createState() => _JourneyInsightsScreenState();
}

class _JourneyInsightsScreenState extends State<JourneyInsightsScreen> {
  late final TravelInsightsService _service =
      widget.service ?? TravelInsightsService();
  late Future<TravelInsights> _future = _service.build();

  void _reload() {
    setState(() => _future = _service.build());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: AuthPalette.cream,
        appBar: AppBar(
          backgroundColor: AuthPalette.maroon,
          foregroundColor: Colors.white,
          title: const Text('Journey insights'),
          actions: [
            IconButton(
              tooltip: 'Refresh insights',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFE8C9D3),
            tabs: [
              Tab(text: 'DNA'),
              Tab(text: 'Gaps'),
              Tab(text: 'Ideas'),
            ],
          ),
        ),
        body: FutureBuilder<TravelInsights>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(message: snapshot.error.toString());
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final insights = snapshot.data!;
            return TabBarView(
              children: [
                _DnaTab(dna: insights.dna),
                _GapTab(gaps: insights.gapAnalysis),
                _IdeasTab(recommendations: insights.recommendations),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DnaTab extends StatelessWidget {
  const _DnaTab({required this.dna});

  final JourneyDnaModel dna;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PrivacyNote(),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Journey DNA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AuthPalette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dna.summary,
                  style: const TextStyle(height: 1.4),
                ),
                if (dna.traits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final trait in dna.traits)
                        AppInfoChip(label: trait),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Built from your visits, journal entries, photo captions, and the '
          'experience types of the districts you have visited.',
          style: TextStyle(color: AuthPalette.mutedText, height: 1.4),
        ),
      ],
    );
  }
}

class _GapTab extends StatelessWidget {
  const _GapTab({required this.gaps});

  final GapAnalysisModel gaps;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PrivacyNote(),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gaps.coveragePercent}% district coverage',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AuthPalette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have recorded visits in ${gaps.visitedDistricts} of '
                  '${gaps.targetDistricts} published districts.',
                ),
                if (gaps.missingExperienceTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Experience types not covered yet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in gaps.missingExperienceTypes)
                        AppInfoChip(label: type),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (gaps.unvisitedDistricts.isEmpty)
          const Text('You have covered every published district.')
        else ...[
          const Text(
            'Districts not visited yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            gaps.unvisitedDistricts.join(', '),
            style: const TextStyle(
              color: AuthPalette.mutedText,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _IdeasTab extends StatelessWidget {
  const _IdeasTab({required this.recommendations});

  final List<RecommendationModel> recommendations;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const AppEmptyState(
        icon: Icons.explore_outlined,
        title: 'No new ideas right now',
        message: 'Visit more places or add journal entries to get suggestions.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recommendations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final idea = recommendations[index];
        return Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.explore, color: AuthPalette.purple),
            title: Text(
              idea.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(idea.reason),
            trailing: AppInfoChip(label: idea.experienceType),
          ),
        );
      },
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EDF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCCBE6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: AuthPalette.maroon, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Insights are calculated for you only. Other users cannot see '
              'your DNA, gaps, or suggestions.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

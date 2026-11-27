import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import '../insights/journey_insights_screen.dart';
import '../journal/journal_screen.dart';
import '../photos/photos_screen.dart';
import '../reviews/my_reviews_screen.dart';
import '../settings/settings_screen.dart';
import '../visits/visits_screen.dart';

/// The home screen for a signed-in traveller.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onSignOut,
    this.email,
    this.onRefreshAuthorization,
  });

  final VoidCallback onSignOut;
  final VoidCallback? onRefreshAuthorization;

  /// Shown as "Signed in as ..." when it is known.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final destinations = <_Destination>[
      _Destination(
        icon: Icons.map_outlined,
        label: 'My visits',
        subtitle: 'Places you have explored',
        builder: (_) => const VisitsScreen(),
      ),
      _Destination(
        icon: Icons.menu_book_outlined,
        label: 'My journal',
        subtitle: 'Private travel memories',
        builder: (_) => const JournalScreen(),
      ),
      _Destination(
        icon: Icons.photo_library_outlined,
        label: 'My photos',
        subtitle: 'Kept in your private folder',
        builder: (_) => const PhotosScreen(),
      ),
      _Destination(
        icon: Icons.fingerprint,
        label: 'Journey DNA',
        subtitle: 'What your travels say about you',
        builder: (_) => const JourneyInsightsScreen(initialIndex: 0),
      ),
      _Destination(
        icon: Icons.insights_outlined,
        label: 'Gap analysis',
        subtitle: 'Coverage and missing experiences',
        builder: (_) => const JourneyInsightsScreen(initialIndex: 1),
      ),
      _Destination(
        icon: Icons.explore_outlined,
        label: 'Recommendations',
        subtitle: 'Ideas matched to your DNA',
        builder: (_) => const JourneyInsightsScreen(initialIndex: 2),
      ),
      _Destination(
        icon: Icons.reviews_outlined,
        label: 'My reviews',
        subtitle: 'Public, display name only',
        builder: (_) => const MyReviewsScreen(),
      ),
      _Destination(
        icon: Icons.settings_outlined,
        label: 'Settings',
        subtitle: 'Data use and privacy',
        builder: (_) => SettingsScreen(email: email),
      ),
    ];

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      appBar: AppBar(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: onSignOut,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.explore,
                    color: AuthPalette.maroon,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to MyYatra',
                    textAlign: TextAlign.center,
                    style: authHeadingStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  if (email != null) ...[
                    Text(
                      'Signed in as $email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AuthPalette.mutedText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const Text(
                    'Your private travel story, all in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthPalette.mutedText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EDF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDCCBE6)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: AuthPalette.maroon,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Visits, journal entries, and photos stay hidden '
                            'from every other user.',
                            style: TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final destination in destinations) ...[
                    _DestinationCard(
                      destination: destination,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: destination.builder,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  if (onRefreshAuthorization != null)
                    TextButton(
                      onPressed: onRefreshAuthorization,
                      child: const Text('Refresh authorization'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final WidgetBuilder builder;
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination, required this.onTap});

  final _Destination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(destination.icon, color: AuthPalette.purple),
        title: Text(
          destination.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(destination.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

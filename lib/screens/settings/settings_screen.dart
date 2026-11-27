import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import 'data_use_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      appBar: AppBar(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (email != null && email!.isNotEmpty) ...[
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.account_circle_outlined,
                    color: AuthPalette.purple,
                  ),
                  title: const Text('Signed in'),
                  subtitle: Text(email!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AuthPalette.maroon,
                ),
                title: const Text('Data use'),
                subtitle: const Text(
                  'See the inputs used for Journey DNA, gap analysis, and '
                  'recommendations.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DataUseScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(Icons.lock_outline, color: AuthPalette.purple),
                title: Text('Privacy'),
                subtitle: Text(
                  'Your visits, journal entries, and photos are visible only to '
                  'you. Public reviews show your display name only.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

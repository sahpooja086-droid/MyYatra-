import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';

/// The simplest possible home screen for a signed-in user.
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
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      appBar: AppBar(
        backgroundColor: AuthPalette.maroon,
        foregroundColor: Colors.white,
        title: const Text('Dashboard'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.explore,
                    color: AuthPalette.maroon,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to MyYatra',
                    textAlign: TextAlign.center,
                    style: authHeadingStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 10),
                  if (email != null) ...[
                    Text(
                      'Signed in as $email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AuthPalette.mutedText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  const Text(
                    'Your travel dashboard is coming soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthPalette.mutedText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AuthPrimaryButton(
                    label: 'Sign out',
                    trailingIcon: Icons.logout,
                    onPressed: onSignOut,
                  ),
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

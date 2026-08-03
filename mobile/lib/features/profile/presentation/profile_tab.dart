import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_profile_repository.dart';
import '../../../shared/widgets/profile_avatar.dart';

/// Profile tab inside the bottom navigation shell.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.api,
    required this.session,
    required this.profile,
    required this.onLogout,
    required this.onOpenProfileEditor,
    required this.onOpenSettings,
  });

  final ApiClient api;
  final Session session;
  final CustomerProfile profile;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfileEditor;
  final VoidCallback onOpenSettings;

  String get _initials {
    final name = profile.name.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: context.brandCard,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    ProfileAvatar(
                      initials: _initials,
                      photoDataUri: profile.profileImage.isEmpty
                          ? null
                          : profile.profileImage,
                      radius: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+91 ${profile.phone}',
                            style: TextStyle(color: context.brandMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              color: context.brandCard,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenProfileEditor,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
              ),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

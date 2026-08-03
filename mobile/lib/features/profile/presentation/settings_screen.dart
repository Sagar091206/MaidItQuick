import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/booking_history_screen.dart';
import '../data/customer_profile_repository.dart';
import 'customer_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    required this.onProfileSaved,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final Future<void> Function(CustomerProfile profile) onProfileSaved;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CustomerProfile? _profile;
  bool _emailNotifications = false;
  bool _loading = true;
  bool _savingPrefs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile =
          await CustomerProfileRepository(widget.api).fetch(widget.session.token);
      final prefs = await widget.api
              .get('/notifications/preferences', token: widget.session.token)
          as Map;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _emailNotifications = prefs['emailNotifications'] as bool? ?? false;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load settings right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<CustomerProfile>(
      MaterialPageRoute(
        builder: (context) => CustomerProfileScreen(
          api: widget.api,
          session: widget.session,
          initialProfile: profile,
          requiredSetup: false,
        ),
      ),
    );
    if (saved != null && mounted) {
      await widget.onProfileSaved(saved);
      setState(() => _profile = saved);
    }
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (_savingPrefs) return;
    setState(() {
      _emailNotifications = value;
      _savingPrefs = true;
    });
    try {
      await widget.api.post(
        '/notifications/preferences',
        {'emailNotifications': value},
        token: widget.session.token,
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
      if (mounted) setState(() => _emailNotifications = !value);
    } catch (_) {
      _showMessage('Could not update preferences.');
      if (mounted) setState(() => _emailNotifications = !value);
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _pickTheme() async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: widget.themeMode,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Appearance',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: Text('Dark'),
                subtitle: Text('Default brand look'),
              ),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: Text('Light'),
              ),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: Text('System'),
                subtitle: Text('Follow the device setting'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (mode != null && mode != widget.themeMode && mounted) {
      await widget.onThemeModeChanged(mode);
    }
  }

  Future<void> _openBookings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingHistoryScreen(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You can sign back in any time with your mobile number.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onLogout();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String get _initials {
    final name = _profile?.name.trim() ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    color: context.brandCard,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            initials: _initials,
                            photoDataUri: profile?.profileImage,
                            radius: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.name ?? 'Customer',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.phone ?? '',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: context.brandMuted),
                                ),
                                if ((profile?.email ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    profile!.email,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: context.brandMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _editProfile,
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preferences',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: context.brandMuted),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: context.brandCard,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.email_outlined),
                          title: const Text('Email notifications'),
                          subtitle: const Text('Booking updates by email'),
                          value: _emailNotifications,
                          onChanged:
                              _savingPrefs ? null : _toggleEmailNotifications,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Appearance'),
                          subtitle: Text(switch (widget.themeMode) {
                            ThemeMode.dark => 'Dark',
                            ThemeMode.light => 'Light',
                            ThemeMode.system => 'System',
                          }),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _pickTheme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: context.brandMuted),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: context.brandCard,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('My bookings'),
                          subtitle:
                              const Text('History, details and actions'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openBookings,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.logout,
                              color: theme.colorScheme.error),
                          title: Text('Sign out',
                              style: TextStyle(
                                  color: theme.colorScheme.error)),
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

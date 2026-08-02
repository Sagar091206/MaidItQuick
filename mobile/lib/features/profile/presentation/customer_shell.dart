import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../navigation/presentation/customer_bottom_nav.dart';
import '../data/customer_profile_repository.dart';
import 'customer_profile_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final Future<void> Function(Session session) onSessionUpdated;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  CustomerProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile =
          await CustomerProfileRepository(widget.api).fetch(widget.session.token);
      if (mounted) setState(() => _profile = profile);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not reach the server. Check your connection and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleProfileSaved(CustomerProfile profile) async {
    final updated = Session(
      token: widget.session.token,
      role: widget.session.role,
      name: profile.name,
    );
    await widget.onSessionUpdated(updated);
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = _profile;
    if (profile == null || !profile.profileComplete) {
      return CustomerProfileScreen(
        api: widget.api,
        session: widget.session,
        initialProfile: profile,
        requiredSetup: true,
        onSaved: _handleProfileSaved,
      );
    }

    return CustomerBottomNav(
      api: widget.api,
      session: widget.session,
      profile: profile,
      onLogout: widget.onLogout,
      onSessionUpdated: widget.onSessionUpdated,
      onProfileSaved: _handleProfileSaved,
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }
}

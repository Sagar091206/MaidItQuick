import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/mvp_home_screen.dart';
import '../data/customer_profile_repository.dart';
import '../../onboarding/presentation/journey_screens.dart';
import 'customer_profile_screen.dart';
import 'settings_screen.dart';
import '../../booking/presentation/booking_history_screen.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
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

  Future<void> _openProfileEditor() async {
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
    if (saved != null) await _handleProfileSaved(saved);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          onProfileSaved: _handleProfileSaved,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
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

    return MvpHomeScreen(
      api: widget.api,
      session: widget.session,
      onLogout: widget.onLogout,
      onOpenSettings: _openSettings,
      onBookService: _openBookingFlow,
      onOpenBookings: _openBookings,
    );
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
    if (mounted) await _loadProfile();
  }

  Future<void> _openBookingFlow() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CustomerJourneyScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          onEditProfile: _openProfileEditor,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/booking_history_screen.dart';
import '../../booking/data/customer_addresses_repository.dart';
import '../../booking/presentation/booking_wizard_screen.dart';
import '../../home/presentation/mvp_home_screen.dart';
import '../../instant/presentation/instant_maid_screen.dart';
import '../../notifications/presentation/alerts_screen.dart';
import '../../profile/data/customer_profile_repository.dart';
import '../../profile/presentation/customer_profile_screen.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../profile/presentation/settings_screen.dart';

/// Root scaffold for the signed-in customer: a Material 3 bottom
/// navigation bar with Home / Bookings / Notifications / Profile tabs.
class CustomerBottomNav extends StatefulWidget {
  const CustomerBottomNav({
    super.key,
    required this.api,
    required this.session,
    required this.profile,
    required this.onLogout,
    required this.onSessionUpdated,
    required this.onProfileSaved,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ApiClient api;
  final Session session;
  final CustomerProfile profile;
  final VoidCallback onLogout;
  final Future<void> Function(Session session) onSessionUpdated;
  final Future<void> Function(CustomerProfile profile) onProfileSaved;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<CustomerBottomNav> createState() => _CustomerBottomNavState();
}

class _CustomerBottomNavState extends State<CustomerBottomNav> {
  int _index = 0;

  void _switchTab(int index) => setState(() => _index = index);

  Future<void> _openBookingFlow() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingWizardScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openInstantMaid() async {
    final addresses = await CustomerAddressesRepository(widget.api)
        .list(widget.session.token);
    CustomerAddress? selected;
    for (final address in addresses) {
      if (address.defaultAddress) {
        selected = address;
        break;
      }
    }
    selected ??= addresses.isEmpty ? null : addresses.first;
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (context) => InstantMaidScreen(
            api: widget.api, session: widget.session, address: selected)));
  }

  Future<void> _openProfileEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CustomerProfileScreen(
          api: widget.api,
          session: widget.session,
          initialProfile: widget.profile,
          requiredSetup: false,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          onProfileSaved: widget.onProfileSaved,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final api = widget.api;
    final pages = [
      MvpHomeScreen(
        api: api,
        session: session,
        onLogout: widget.onLogout,
        onOpenSettings: _openSettings,
        onBookService: _openBookingFlow,
        onOpenBookings: () => _switchTab(1),
        onInstantMaid: _openInstantMaid,
      ),
      BookingHistoryScreen(
        api: api,
        session: session,
      ),
      AlertsScreen(
        api: api,
        session: session,
      ),
      ProfileTab(
        api: api,
        session: session,
        profile: widget.profile,
        onLogout: widget.onLogout,
        onOpenProfileEditor: _openProfileEditor,
        onOpenSettings: _openSettings,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _switchTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

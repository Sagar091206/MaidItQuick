# US-02 — Bottom Navigation Shell

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-01 (shared widgets).
> This story creates **one new file**, modifies **one file** (`customer_shell.dart`), and leaves every other screen untouched.

## 1. Objective

Introduce a Material 3 `NavigationBar` with four tabs for the signed-in customer: **Home**, **Bookings**, **Notifications**, **Profile**. The shell keeps the existing profile-completeness gate; once the profile is complete it renders the tabbed shell instead of a single home screen.

## 2. Scope

- **In:** `features/navigation/presentation/customer_bottom_nav.dart`; wiring in `features/profile/presentation/customer_shell.dart`.
- **Out:** no changes to `mvp_home_screen.dart` (US-03), `booking_history_screen.dart` (US-11), `customer_profile_screen.dart`, `settings_screen.dart`. Notifications tab is a placeholder that US-13 replaces. Profile tab is minimal here; US-12 enriches it.

## 3. Tech stack details

- Flutter, Material 3 `NavigationBar`.
- Vanilla `setState` navigation index; constructor DI (`ApiClient`, `Session`).
- Reuses `EmptyStateView` from US-01.

## 4. Files

| File | Action |
|---|---|
| `mobile/lib/features/navigation/presentation/customer_bottom_nav.dart` | **New** |
| `mobile/lib/features/profile/presentation/customer_shell.dart` | Modify: render `CustomerBottomNav` after profile-complete |

## 5. Implementation — Dart

### 5.1 New file: `customer_bottom_nav.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/booking_history_screen.dart';
import '../../home/presentation/mvp_home_screen.dart';
import '../../onboarding/presentation/customer_journey_screen.dart';
import '../../profile/data/customer_profile_repository.dart';
import '../../profile/presentation/customer_profile_screen.dart';
import '../../profile/presentation/settings_screen.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../shared/widgets/app_states.dart';

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
    // US-05 replaces this route with the new BookingWizardScreen.
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
      ),
      BookingHistoryScreen(
        api: api,
        session: session,
        onLogout: widget.onLogout,
      ),
      const _NotificationsPlaceholder(),
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

/// Placeholder until US-13 ships the notifications inbox.
class _NotificationsPlaceholder extends StatelessWidget {
  const _NotificationsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            EmptyStateView(
              icon: Icons.notifications_none,
              title: 'No alerts yet',
              message:
                  'Booking updates, OTPs and service notifications will appear here.',
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: `ProfileTab` is created in this story (below) and kept minimal; US-12 extends it with address management.

### 5.2 New file: `features/profile/presentation/profile_tab.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_profile_repository.dart';
import 'profile_avatar.dart';

/// Profile tab inside the bottom navigation shell.
/// US-12 adds saved-addresses entry and richer menu items.
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
                      imageBase64: profile.profileImage,
                      name: profile.name,
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
```

### 5.3 Modify `customer_shell.dart`

Replace the final `return MvpHomeScreen(...)` block (currently lines ~131–138) with:

```dart
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
```

Also update imports: add

```dart
import '../../navigation/presentation/customer_bottom_nav.dart';
```

and remove the now-unused `MvpHomeScreen` import and the `_openBookingFlow`/`_openBookings` methods (tab switching lives inside the nav). Keep `_loadProfile`, `_handleProfileSaved`, `_openProfileEditor`, `_openSettings` — they are still used.

## 6. State handling

- `IndexedStack` preserves each tab's state (dashboard not refetched on tab switches).
- Home tab "View history" switches to the Bookings tab instead of pushing a route.
- The profile-completeness gate in `customer_shell.dart` is unchanged.

## 7. Tests

`mobile/test/features/navigation/customer_bottom_nav_test.dart` (new):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/core/brand_theme.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/navigation/presentation/customer_bottom_nav.dart';
import 'package:maiditquick_mobile/features/profile/data/customer_profile_repository.dart';

void main() {
  testWidgets('shows four destinations and switches tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: maidItQuickLightTheme(),
      home: CustomerBottomNav(
        api: ApiClient(),
        session: const Session(token: 't', role: UserRole.customer, name: 'Riya'),
        profile: const CustomerProfile(
          name: 'Riya',
          phone: '9000000000',
          email: '',
          gender: '',
          dob: '',
          profileImage: '',
          profileComplete: true,
        ),
        onLogout: () {},
        onSessionUpdated: (_) async {},
        onProfileSaved: (_) async {},
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) async {},
      ),
    ));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
```

> Note: the session/profile types above are illustrative — match the exact constructors of `Session` and `CustomerProfile` in your codebase (`features/auth/data/auth_repository.dart`, `features/profile/data/customer_profile_repository.dart`).

## 8. Verification

```
cd D:\MaidItQuick\mobile
flutter analyze
flutter test test/features/navigation/customer_bottom_nav_test.dart
```

## 9. Acceptance criteria

- [ ] Four-tab `NavigationBar` renders after profile completion.
- [ ] Tab state preserved via `IndexedStack`.
- [ ] Home "View history" opens the Bookings tab.
- [ ] Profile tab shows avatar, name, phone, edit/settings/logout.
- [ ] No onboarding or auth file modified.

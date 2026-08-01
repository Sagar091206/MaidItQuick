import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/partner_repository.dart';
import 'incoming_booking_request_screen.dart';
import 'partner_alerts_tab.dart';
import 'partner_bookings_tab.dart';
import 'partner_earnings_tab.dart';
import 'partner_profile_tab.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    this.initialProfile,
    this.onManageVerification,
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final Map<String, dynamic>? initialProfile;
  final ValueChanged<int>? onManageVerification;

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  int _selectedDashboardTab = 0;
  bool _loading = true;
  bool _availabilityChanging = false;
  String? _error;

  late final PartnerRepository _partnerRepository = PartnerRepository(widget.api);

  @override
  void initState() {
    super.initState();
    _dashboard = widget.initialProfile == null
        ? null
        : Map<String, dynamic>.from(widget.initialProfile!);
    _loadDashboard(showMessage: false);
  }

  Future<void> _loadDashboard({bool showMessage = true}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dashboard =
          await _partnerRepository.fetchProfile(widget.session.token);

      if (!mounted) return;
      setState(() {
        _dashboard = {
          ...?_dashboard,
          ...dashboard,
        };
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (showMessage) _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Dashboard data is currently unavailable.';
      setState(() => _error = message);
      if (showMessage) _showMessage(message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setOnline(bool online) async {
    if (!_eligible) {
      _showMessage(
        'Complete all account requirements before going online.',
      );
      return;
    }

    setState(() => _availabilityChanging = true);

    try {
      final response = await _partnerRepository.setAvailability(
        widget.session.token,
        online ? 'AVAILABLE' : 'OFFLINE',
      );

      if (!mounted) return;
      setState(() {
        _dashboard = {
          ...?_dashboard,
          ...response,
          'online': online,
          'availabilityStatus': online ? 'ONLINE' : 'OFFLINE',
        };
      });

      _showMessage(
        online
            ? 'You are online and can receive booking requests.'
            : 'You are now offline.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Online status change failed.');
    } finally {
      if (mounted) setState(() => _availabilityChanging = false);
    }
  }

  bool get _eligible {
    final applicationStatus = (_dashboard?['applicationStatus'] ??
            _dashboard?['approvalStatus'] ??
            _dashboard?['status'])
        ?.toString()
        .toUpperCase();

    return _dashboard?['eligible'] == true ||
        _dashboard?['accountEligible'] == true ||
        _dashboard?['readyForJobs'] == true ||
        applicationStatus == 'APPROVED';
  }

  bool get _online {
    final value = _dashboard?['online'] ??
        _dashboard?['isOnline'] ??
        _dashboard?['availabilityStatus'];

    if (value is bool) return value;

    final status = value?.toString().toUpperCase();
    return status == 'ONLINE' || status == 'AVAILABLE' || status == 'TRUE';
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _count(dynamic value, int fallback) {
    if (value is num) return value.toInt().toString();
    return (int.tryParse(value?.toString() ?? '') ?? fallback).toString();
  }

  /// Formats a rupee amount. Numeric values are treated as rupees; strings
  /// that already carry a currency symbol are returned unchanged.
  String _money(dynamic value) {
    if (value == null) return '₹0';

    if (value is num) {
      final amount = value < 0 ? value.abs() : value;
      final digits = amount % 1 == 0 ? 0 : 2;
      return '₹${amount.toStringAsFixed(digits)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '₹0';
    return text.startsWith('₹') ? text : '₹$text';
  }

  /// Converts a paise value (the API's canonical money unit) to rupees.
  String _paise(dynamic value) {
    if (value == null) return '₹0';
    final paise = value is num ? value : double.tryParse(value.toString());
    if (paise == null) return '₹0';
    return _money(paise / 100);
  }

  /// Reads an amount that the API may expose as rupees (preferred) or paise.
  String _amount(
    Map<String, dynamic> data,
    List<String> rupeesKeys,
    List<String> paiseKeys,
  ) {
    for (final key in rupeesKeys) {
      if (data[key] != null) return _money(data[key]);
    }
    for (final key in paiseKeys) {
      if (data[key] != null) return _paise(data[key]);
    }
    return '₹0';
  }

  String _nextBooking(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) return 'No booking scheduled';

    final first = bookings.first;
    return (first['time'] ??
            first['scheduledFor'] ??
            first['scheduledTime'] ??
            'Next booking scheduled')
        .toString();
  }

  Future<void> _openBooking(Map<String, dynamic> booking) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IncomingBookingRequestScreen(
          api: widget.api,
          session: widget.session,
          booking: booking,
        ),
      ),
    );

    // Whether the partner accepted, rejected, or the request expired, the
    // booking list is stale afterwards — refresh it on return.
    if (!mounted) return;
    await _loadDashboard(showMessage: false);
  }

  void _openPendingAction(Map<String, dynamic> action) {
    _showMessage(
      (action['message'] ??
              action['description'] ??
              'Complete the requested account action.')
          .toString(),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _dashboard ?? const <String, dynamic>{};
    final requests = _list(data['newRequests'] ?? data['bookingRequests']);
    final todayBookings = _list(data['todayBookings'] ?? data['bookingsToday']);
    final upcomingBookings = _list(data['upcomingBookings']);
    final pendingActions = _list(data['pendingActions']);
    final notifications = _list(data['notifications']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner dashboard'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadDashboard(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDashboardTab,
        onDestinationSelected: (index) {
          setState(() => _selectedDashboardTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
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
      body: _selectedDashboardTab == 0
          ? (_loading && _dashboard == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: () => _loadDashboard(showMessage: false),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${widget.session.name}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Here is your work summary for today.',
                                    style: TextStyle(color: BrandColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: _online,
                                  onChanged: !_eligible || _availabilityChanging
                                      ? null
                                      : _setOnline,
                                ),
                                Text(
                                  _online ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _online
                                        ? BrandColors.lime
                                        : BrandColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _EligibilityCard(
                          eligible: _eligible,
                          online: _online,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _DashboardMessageCard(
                            title: 'Dashboard load failed',
                            message: _error!,
                          ),
                        ],
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: [
                            _MetricCard(
                              icon: Icons.notifications_active_outlined,
                              label: 'New requests',
                              value: _count(
                                data['newRequestCount'],
                                requests.length,
                              ),
                              helper: 'Waiting for response',
                            ),
                            _MetricCard(
                              icon: Icons.calendar_today_outlined,
                              label: 'Today bookings',
                              value: _count(
                                data['todayBookingCount'],
                                todayBookings.length,
                              ),
                              helper: _nextBooking(todayBookings),
                            ),
                            _MetricCard(
                              icon: Icons.currency_rupee_outlined,
                              label: 'Today earnings',
                              value: _amount(
                                data,
                                const ['todayEarnings', 'currentEarnings'],
                                const ['todayEarningsPaise'],
                              ),
                              helper: 'Current earnings',
                            ),
                            _MetricCard(
                              icon: Icons.star_outline,
                              label: 'Rating',
                              value: (data['rating'] ??
                                      data['averageRating'] ??
                                      '—')
                                  .toString(),
                              helper:
                                  '${data['completedJobs'] ?? 0} completed jobs',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const _SectionTitle(title: 'Booking activity'),
                        const SizedBox(height: 10),
                        if (requests.isEmpty &&
                            todayBookings.isEmpty &&
                            upcomingBookings.isEmpty)
                          const _EmptyCard(
                            icon: Icons.event_available_outlined,
                            title: 'No bookings yet',
                            message:
                                'New requests and upcoming bookings will appear here.',
                          )
                        else ...[
                          ...requests.take(2).map(
                                (booking) => PartnerBookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                          ...todayBookings.take(2).map(
                                (booking) => PartnerBookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                          ...upcomingBookings.take(2).map(
                                (booking) => PartnerBookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                        ],
                        const SizedBox(height: 22),
                        const _SectionTitle(title: 'Earnings'),
                        const SizedBox(height: 10),
                        _EarningsCard(
                          weeklyEarnings: _amount(
                            data,
                            const ['weeklyEarnings'],
                            const ['weeklyEarningsPaise'],
                          ),
                          completedJobs:
                              (data['completedJobs'] ?? 0).toString(),
                          incentives: _amount(
                            data,
                            const ['incentives'],
                            const ['incentivesPaise'],
                          ),
                          onView: () =>
                              setState(() => _selectedDashboardTab = 2),
                        ),
                        const SizedBox(height: 22),
                        const _SectionTitle(title: 'Pending actions'),
                        const SizedBox(height: 10),
                        if (pendingActions.isEmpty && notifications.isEmpty)
                          const _EmptyCard(
                            icon: Icons.task_alt_outlined,
                            title: 'No pending actions',
                            message: 'Your account is up to date.',
                          )
                        else ...[
                          ...pendingActions.take(3).map(
                                (action) => _ActionCard(
                                  action: action,
                                  onTap: () => _openPendingAction(action),
                                ),
                              ),
                          _NotificationCard(
                            count: notifications.length,
                            onTap: () =>
                                setState(() => _selectedDashboardTab = 3),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          _loading
                              ? 'Refreshing dashboard...'
                              : 'Pull down to refresh critical booking information.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
          : _DashboardTabPage(
              index: _selectedDashboardTab,
              dashboard: data,
              requests: requests,
              todayBookings: todayBookings,
              upcomingBookings: upcomingBookings,
              pendingActions: pendingActions,
              notifications: notifications,
              onOpenBooking: _openBooking,
              onRefresh: () => _loadDashboard(showMessage: false),
              onLogout: widget.onLogout,
              onManageVerification: widget.onManageVerification,
            ),
    );
  }
}

class _DashboardTabPage extends StatelessWidget {
  const _DashboardTabPage({
    required this.index,
    required this.dashboard,
    required this.requests,
    required this.todayBookings,
    required this.upcomingBookings,
    required this.pendingActions,
    required this.notifications,
    required this.onOpenBooking,
    required this.onRefresh,
    required this.onLogout,
    required this.onManageVerification,
  });

  final int index;
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> todayBookings;
  final List<Map<String, dynamic>> upcomingBookings;
  final List<Map<String, dynamic>> pendingActions;
  final List<Map<String, dynamic>> notifications;
  final ValueChanged<Map<String, dynamic>> onOpenBooking;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;
  final ValueChanged<int>? onManageVerification;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      1 => PartnerBookingsTab(
          requests: requests,
          todayBookings: todayBookings,
          upcomingBookings: upcomingBookings,
          onOpenBooking: onOpenBooking,
          onRefresh: onRefresh,
        ),
      2 => PartnerEarningsTab(
          dashboard: dashboard,
          onRefresh: onRefresh,
        ),
      3 => PartnerAlertsTab(
          pendingActions: pendingActions,
          notifications: notifications,
          onRefresh: onRefresh,
        ),
      4 => PartnerProfileTab(
          dashboard: dashboard,
          onLogout: onLogout,
          onManageVerification: onManageVerification,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({
    required this.eligible,
    required this.online,
  });

  final bool eligible;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final accent = eligible ? BrandColors.lime : Colors.orangeAccent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              eligible
                  ? (online
                      ? Icons.radio_button_checked
                      : Icons.verified_outlined)
                  : Icons.lock_outline,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eligible
                        ? (online ? 'You are online' : 'Account eligible')
                        : 'Account requirements incomplete',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eligible
                        ? (online
                            ? 'You can receive new booking requests.'
                            : 'Turn online when you are ready to work.')
                        : 'Complete all required checks before going online.',
                    style: const TextStyle(color: BrandColors.muted),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BrandColors.lime),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.weeklyEarnings,
    required this.completedJobs,
    required this.incentives,
    required this.onView,
  });

  final String weeklyEarnings;
  final String completedJobs;
  final String incentives;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ValueRow(label: 'This week', value: weeklyEarnings),
            const Divider(height: 24),
            _ValueRow(label: 'Completed jobs', value: completedJobs),
            const SizedBox(height: 12),
            _ValueRow(label: 'Incentives', value: incentives),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onView,
              child: const Text('View earnings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: BrandColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onTap,
  });

  final Map<String, dynamic> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_outlined),
        title: Text(
          action['title']?.toString() ??
              action['label']?.toString() ??
              'Pending action',
        ),
        subtitle: Text(
          action['message']?.toString() ??
              action['description']?.toString() ??
              'Complete this action to keep your account updated.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        subtitle: Text(
          count == 0
              ? 'You have no unread notifications.'
              : 'You have $count unread notification${count == 1 ? '' : 's'}.',
        ),
        trailing: count == 0
            ? const Icon(Icons.chevron_right)
            : CircleAvatar(
                radius: 14,
                backgroundColor: BrandColors.lime,
                foregroundColor: BrandColors.evergreen,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: BrandColors.muted, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BrandColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMessageCard extends StatelessWidget {
  const _DashboardMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.cloud_off_outlined,
          color: Colors.orangeAccent,
        ),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';

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
      final result = await widget.api.get(
        '/workers/me',
        token: widget.session.token,
      );

      final dashboard = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};

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
      final result = await widget.api.post(
        '/workers/me/availability',
        {'status': online ? 'AVAILABLE' : 'OFFLINE'},
        token: widget.session.token,
      );

      final response = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};

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

  String _money(dynamic value) {
    if (value == null) return '₹0';

    if (value is num) {
      final amount = value.abs() >= 10000 ? value / 100 : value;
      return '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '₹0';
    return text.startsWith('₹') ? text : '₹$text';
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
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IncomingBookingRequestScreen(
          api: widget.api,
          session: widget.session,
          booking: booking,
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'accepted' || result == 'rejected') {
      await _loadDashboard(showMessage: false);
    }
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
                              value: _money(
                                data['todayEarnings'] ??
                                    data['currentEarnings'] ??
                                    data['todayEarningsPaise'],
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
                                (booking) => _BookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                          ...todayBookings.take(2).map(
                                (booking) => _BookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                          ...upcomingBookings.take(2).map(
                                (booking) => _BookingCard(
                                  booking: booking,
                                  onOpen: () => _openBooking(booking),
                                ),
                              ),
                        ],
                        const SizedBox(height: 22),
                        const _SectionTitle(title: 'Earnings'),
                        const SizedBox(height: 10),
                        _EarningsCard(
                          weeklyEarnings: _money(
                            data['weeklyEarnings'] ??
                                data['weeklyEarningsPaise'],
                          ),
                          completedJobs:
                              (data['completedJobs'] ?? 0).toString(),
                          incentives: _money(
                            data['incentives'] ?? data['incentivesPaise'],
                          ),
                          onView: () =>
                              _showMessage('Opening earnings details.'),
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
                            onTap: () => _showMessage('Opening notifications.'),
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
      1 => _BookingsTab(
          requests: requests,
          todayBookings: todayBookings,
          upcomingBookings: upcomingBookings,
          onOpenBooking: onOpenBooking,
          onRefresh: onRefresh,
        ),
      2 => _EarningsTab(
          dashboard: dashboard,
          onRefresh: onRefresh,
        ),
      3 => _AlertsTab(
          pendingActions: pendingActions,
          notifications: notifications,
          onRefresh: onRefresh,
        ),
      4 => _ProfileTab(
          dashboard: dashboard,
          onLogout: onLogout,
          onManageVerification: onManageVerification,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({
    required this.requests,
    required this.todayBookings,
    required this.upcomingBookings,
    required this.onOpenBooking,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> todayBookings;
  final List<Map<String, dynamic>> upcomingBookings;
  final ValueChanged<Map<String, dynamic>> onOpenBooking;
  final Future<void> Function() onRefresh;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String _selectedFilter = 'ALL';

  static const filters = [
    'ALL',
    'NEW',
    'ACCEPTED',
    'ACTIVE',
    'COMPLETED',
    'CANCELLED',
  ];

  String _statusOf(Map<String, dynamic> booking) {
    return (booking['status'] ?? booking['bookingStatus'] ?? 'NEW')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(' ', '_');
  }

  List<Map<String, dynamic>> get _allBookings {
    final seen = <String>{};
    final combined = <Map<String, dynamic>>[];

    for (final booking in [
      ...widget.requests,
      ...widget.todayBookings,
      ...widget.upcomingBookings,
    ]) {
      final id = (booking['id'] ??
              booking['bookingId'] ??
              booking['bookingCode'] ??
              booking.hashCode)
          .toString();

      if (seen.add(id)) {
        combined.add(booking);
      }
    }

    return combined;
  }

  bool _matchesFilter(Map<String, dynamic> booking) {
    if (_selectedFilter == 'ALL') return true;

    final status = _statusOf(booking);

    return switch (_selectedFilter) {
      'NEW' => status == 'NEW' || status == 'REQUESTED' || status == 'PENDING',
      'ACCEPTED' => status == 'ACCEPTED' || status == 'ASSIGNED',
      'ACTIVE' => status == 'TRAVELLING' ||
          status == 'ARRIVED' ||
          status == 'IN_PROGRESS' ||
          status == 'STARTED',
      'COMPLETED' => status == 'COMPLETED' || status == 'DONE',
      'CANCELLED' =>
        status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED',
      _ => true,
    };
  }

  int _countFor(String filter) {
    if (filter == 'ALL') return _allBookings.length;

    final previous = _selectedFilter;
    _selectedFilter = filter;
    final count = _allBookings.where(_matchesFilter).length;
    _selectedFilter = previous;
    return count;
  }

  String _sectionTitle(Map<String, dynamic> booking) {
    final status = _statusOf(booking);

    if (status == 'NEW' || status == 'REQUESTED' || status == 'PENDING') {
      return 'New requests';
    }

    if (status == 'ACCEPTED' || status == 'ASSIGNED') {
      return 'Accepted bookings';
    }

    if (status == 'TRAVELLING' ||
        status == 'ARRIVED' ||
        status == 'IN_PROGRESS' ||
        status == 'STARTED') {
      return 'Active bookings';
    }

    if (status == 'COMPLETED' || status == 'DONE') {
      return 'Completed bookings';
    }

    if (status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED') {
      return 'Cancelled bookings';
    }

    return 'Other bookings';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allBookings.where(_matchesFilter).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final booking in filtered) {
      grouped.putIfAbsent(_sectionTitle(booking), () => []).add(booking);
    }

    const sectionOrder = [
      'New requests',
      'Accepted bookings',
      'Active bookings',
      'Completed bookings',
      'Cancelled bookings',
      'Other bookings',
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Bookings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage new requests, active jobs and booking history.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = filter == _selectedFilter;
                  final count = _countFor(filter);

                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter);
                    },
                    label: Text(
                      '${_filterLabel(filter)} ($count)',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            if (filtered.isEmpty)
              _BookingsEmptyState(
                filter: _selectedFilter,
              )
            else
              ...sectionOrder.expand((title) {
                final bookings = grouped[title];
                if (bookings == null || bookings.isEmpty) {
                  return const <Widget>[];
                }

                return <Widget>[
                  _BookingSectionHeader(
                    title: title,
                    count: bookings.length,
                  ),
                  const SizedBox(height: 10),
                  ...bookings.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingCard(
                        booking: booking,
                        onOpen: () => widget.onOpenBooking(booking),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ];
              }),
          ],
        ),
      ),
    );
  }

  String _filterLabel(String filter) {
    return switch (filter) {
      'ALL' => 'All',
      'NEW' => 'New',
      'ACCEPTED' => 'Accepted',
      'ACTIVE' => 'Active',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => filter,
    };
  }
}

class _BookingSectionHeader extends StatelessWidget {
  const _BookingSectionHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CircleAvatar(
          radius: 13,
          backgroundColor: BrandColors.lime.withValues(alpha: 0.16),
          foregroundColor: BrandColors.lime,
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingsEmptyState extends StatelessWidget {
  const _BookingsEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      'NEW' => 'No new booking requests are waiting.',
      'ACCEPTED' => 'You have no accepted bookings.',
      'ACTIVE' => 'There is no active service right now.',
      'COMPLETED' => 'Completed bookings will appear here.',
      'CANCELLED' => 'You have no cancelled bookings.',
      _ => 'New requests and booking history will appear here.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 42,
              color: BrandColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              filter == 'ALL'
                  ? 'No bookings available'
                  : 'No ${filter.toLowerCase()} bookings',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsTab extends StatefulWidget {
  const _EarningsTab({
    required this.dashboard,
    required this.onRefresh,
  });

  final Map<String, dynamic> dashboard;
  final Future<void> Function() onRefresh;

  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  String _selectedPeriod = 'WEEK';

  static const _periods = ['TODAY', 'WEEK', 'MONTH'];

  String _money(dynamic value) {
    if (value == null) return '₹0';

    if (value is num) {
      final amount = value.abs() >= 10000 ? value / 100 : value;
      return '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '₹0';
    return text.startsWith('₹') ? text : '₹$text';
  }

  List<Map<String, dynamic>> _transactions(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _periodEarnings {
    return switch (_selectedPeriod) {
      'TODAY' => _money(
          widget.dashboard['todayEarnings'] ??
              widget.dashboard['currentEarnings'],
        ),
      'MONTH' => _money(
          widget.dashboard['monthlyEarnings'] ??
              widget.dashboard['monthEarnings'],
        ),
      _ => _money(
          widget.dashboard['weeklyEarnings'] ??
              widget.dashboard['weekEarnings'],
        ),
    };
  }

  String _periodLabel(String period) {
    return switch (period) {
      'TODAY' => 'Today',
      'WEEK' => 'Week',
      'MONTH' => 'Month',
      _ => period,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _transactions(
      widget.dashboard['transactions'] ?? widget.dashboard['earningsHistory'],
    );

    final incentives = _money(
      widget.dashboard['incentives'] ?? widget.dashboard['incentiveEarnings'],
    );

    final deductions = _money(
      widget.dashboard['deductions'] ?? widget.dashboard['totalDeductions'],
    );

    final availableBalance = _money(
      widget.dashboard['availableBalance'] ??
          widget.dashboard['withdrawableBalance'],
    );

    final pendingSettlement = _money(
      widget.dashboard['pendingSettlement'] ??
          widget.dashboard['pendingPayout'],
    );

    final completedJobs = (widget.dashboard['completedJobs'] ?? 0).toString();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Earnings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track earnings, incentives, deductions and settlements.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: _periods
                  .map(
                    (period) => ButtonSegment(
                      value: period,
                      label: Text(_periodLabel(period)),
                    ),
                  )
                  .toList(),
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() => _selectedPeriod = selection.first);
              },
            ),
            const SizedBox(height: 18),
            _PrimaryEarningsCard(
              period: _selectedPeriod,
              amount: _periodEarnings,
              completedJobs: completedJobs,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _EarningsMetricCard(
                  icon: Icons.card_giftcard_outlined,
                  label: 'Incentives',
                  value: incentives,
                ),
                _EarningsMetricCard(
                  icon: Icons.remove_circle_outline,
                  label: 'Deductions',
                  value: deductions,
                ),
                _EarningsMetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Available balance',
                  value: availableBalance,
                ),
                _EarningsMetricCard(
                  icon: Icons.schedule_outlined,
                  label: 'Pending settlement',
                  value: pendingSettlement,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Settlement summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SettlementSummaryCard(
              availableBalance: availableBalance,
              pendingSettlement: pendingSettlement,
              nextSettlement: (widget.dashboard['nextSettlementDate'] ??
                      widget.dashboard['nextPayoutDate'] ??
                      'Not scheduled')
                  .toString(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transaction history',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${transactions.length}',
                  style: const TextStyle(
                    color: BrandColors.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (transactions.isEmpty)
              const _EarningsEmptyState()
            else
              ...transactions.map(
                (transaction) => _EarningsTransactionCard(
                  transaction: transaction,
                  money: _money,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryEarningsCard extends StatelessWidget {
  const _PrimaryEarningsCard({
    required this.period,
    required this.amount,
    required this.completedJobs,
  });

  final String period;
  final String amount;
  final String completedJobs;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      'TODAY' => 'Today’s earnings',
      'MONTH' => 'Monthly earnings',
      _ => 'Weekly earnings',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.task_alt_outlined,
                  color: BrandColors.lime,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text('$completedJobs completed jobs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsMetricCard extends StatelessWidget {
  const _EarningsMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BrandColors.lime),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementSummaryCard extends StatelessWidget {
  const _SettlementSummaryCard({
    required this.availableBalance,
    required this.pendingSettlement,
    required this.nextSettlement,
  });

  final String availableBalance;
  final String pendingSettlement;
  final String nextSettlement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettlementRow(
              label: 'Available balance',
              value: availableBalance,
            ),
            const Divider(height: 24),
            _SettlementRow(
              label: 'Pending settlement',
              value: pendingSettlement,
            ),
            const Divider(height: 24),
            _SettlementRow(
              label: 'Next settlement',
              value: nextSettlement,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
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
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _EarningsTransactionCard extends StatelessWidget {
  const _EarningsTransactionCard({
    required this.transaction,
    required this.money,
  });

  final Map<String, dynamic> transaction;
  final String Function(dynamic) money;

  @override
  Widget build(BuildContext context) {
    final bookingId = (transaction['bookingId'] ??
            transaction['bookingCode'] ??
            transaction['reference'] ??
            '—')
        .toString();

    final service = (transaction['service'] ??
            transaction['serviceName'] ??
            transaction['title'] ??
            'Service')
        .toString();

    final date = (transaction['date'] ??
            transaction['createdAt'] ??
            transaction['completedAt'] ??
            'Date unavailable')
        .toString();

    final net = transaction['netEarning'] ??
        transaction['netAmount'] ??
        transaction['amount'] ??
        0;

    final status =
        (transaction['settlementStatus'] ?? transaction['status'] ?? 'PENDING')
            .toString()
            .toUpperCase();

    final statusColor = status.contains('PAID') ||
            status.contains('SETTLED') ||
            status.contains('COMPLETED')
        ? BrandColors.lime
        : Colors.amber;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: BrandColors.lime.withValues(alpha: 0.16),
          foregroundColor: BrandColors.lime,
          child: const Icon(Icons.currency_rupee),
        ),
        title: Text(
          service,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$bookingId · $date'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(net),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsEmptyState extends StatelessWidget {
  const _EarningsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: BrandColors.muted,
            ),
            SizedBox(height: 12),
            Text(
              'No earnings yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Completed booking payments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsTab extends StatefulWidget {
  const _AlertsTab({
    required this.pendingActions,
    required this.notifications,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> pendingActions;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function() onRefresh;

  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  String _selectedFilter = 'ALL';
  final Set<String> _readIds = <String>{};

  static const filters = [
    'ALL',
    'UNREAD',
    'BOOKINGS',
    'VERIFICATION',
    'PAYMENTS',
    'SYSTEM',
  ];

  List<Map<String, dynamic>> get _items {
    final combined = <Map<String, dynamic>>[];

    for (final action in widget.pendingActions) {
      combined.add({
        ...action,
        '_source': 'ACTION',
      });
    }

    for (final notification in widget.notifications) {
      combined.add({
        ...notification,
        '_source': 'NOTIFICATION',
      });
    }

    return combined;
  }

  String _idOf(Map<String, dynamic> item) {
    return (item['id'] ??
            item['notificationId'] ??
            item['actionId'] ??
            item.hashCode)
        .toString();
  }

  bool _isRead(Map<String, dynamic> item) {
    final id = _idOf(item);
    if (_readIds.contains(id)) return true;

    final value =
        item['read'] ?? item['isRead'] ?? item['seen'] ?? item['isSeen'];

    if (value is bool) return value;

    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == 'read' || normalized == 'seen';
  }

  String _categoryOf(Map<String, dynamic> item) {
    final raw = (item['category'] ??
            item['type'] ??
            item['notificationType'] ??
            item['actionType'] ??
            item['_source'] ??
            'SYSTEM')
        .toString()
        .toUpperCase();

    if (raw.contains('BOOK') ||
        raw.contains('REQUEST') ||
        raw.contains('CANCEL')) {
      return 'BOOKINGS';
    }

    if (raw.contains('KYC') ||
        raw.contains('VERIFY') ||
        raw.contains('DOCUMENT') ||
        raw.contains('APPROVAL')) {
      return 'VERIFICATION';
    }

    if (raw.contains('PAY') ||
        raw.contains('EARNING') ||
        raw.contains('SETTLEMENT') ||
        raw.contains('PAYOUT')) {
      return 'PAYMENTS';
    }

    return 'SYSTEM';
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    if (_selectedFilter == 'ALL') return true;
    if (_selectedFilter == 'UNREAD') return !_isRead(item);
    return _categoryOf(item) == _selectedFilter;
  }

  String _titleOf(Map<String, dynamic> item) {
    return (item['title'] ?? item['label'] ?? item['subject'] ?? 'Notification')
        .toString();
  }

  String _messageOf(Map<String, dynamic> item) {
    return (item['message'] ??
            item['description'] ??
            item['body'] ??
            'Open to view details.')
        .toString();
  }

  String _timeOf(Map<String, dynamic> item) {
    return (item['createdAt'] ??
            item['timestamp'] ??
            item['time'] ??
            item['updatedAt'] ??
            'Recently')
        .toString();
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'BOOKINGS' => Icons.calendar_month_outlined,
      'VERIFICATION' => Icons.verified_user_outlined,
      'PAYMENTS' => Icons.account_balance_wallet_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  void _markRead(Map<String, dynamic> item) {
    setState(() => _readIds.add(_idOf(item)));
  }

  void _markAllRead() {
    setState(() {
      for (final item in _items) {
        _readIds.add(_idOf(item));
      }
    });
  }

  void _openItem(Map<String, dynamic> item) {
    _markRead(item);

    final category = _categoryOf(item);
    final message = switch (category) {
      'BOOKINGS' => 'Opening related booking.',
      'VERIFICATION' => 'Opening verification details.',
      'PAYMENTS' => 'Opening payment details.',
      _ => 'Opening notification details.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where(_matchesFilter).toList();
    final unreadCount = _items.where((item) => !_isRead(item)).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alerts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              unreadCount == 0
                  ? 'You are all caught up.'
                  : '$unreadCount unread alert${unreadCount == 1 ? '' : 's'}.',
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = _selectedFilter == filter;

                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter);
                    },
                    label: Text(_filterLabel(filter)),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            if (filtered.isEmpty)
              _AlertsEmptyState(filter: _selectedFilter)
            else
              ...filtered.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlertCard(
                    icon: _iconFor(_categoryOf(item)),
                    title: _titleOf(item),
                    message: _messageOf(item),
                    time: _timeOf(item),
                    category: _categoryOf(item),
                    read: _isRead(item),
                    onTap: () => _openItem(item),
                    onMarkRead: () => _markRead(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(String filter) {
    return switch (filter) {
      'ALL' => 'All',
      'UNREAD' => 'Unread',
      'BOOKINGS' => 'Bookings',
      'VERIFICATION' => 'Verification',
      'PAYMENTS' => 'Payments',
      'SYSTEM' => 'System',
      _ => filter,
    };
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    required this.read,
    required this.onTap,
    required this.onMarkRead,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final String category;
  final bool read;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  Color get _accent {
    return switch (category) {
      'BOOKINGS' => BrandColors.lime,
      'VERIFICATION' => Colors.amber,
      'PAYMENTS' => Colors.lightBlueAccent,
      _ => BrandColors.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: _accent.withValues(alpha: 0.16),
                    foregroundColor: _accent,
                    child: Icon(icon),
                  ),
                  if (!read)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: BrandColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  read ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        color: BrandColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (!read)
                          TextButton(
                            onPressed: onMarkRead,
                            child: const Text('Mark read'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsEmptyState extends StatelessWidget {
  const _AlertsEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      'UNREAD' => 'You have no unread alerts.',
      'BOOKINGS' => 'Booking alerts will appear here.',
      'VERIFICATION' => 'Verification updates will appear here.',
      'PAYMENTS' => 'Payment alerts will appear here.',
      'SYSTEM' => 'System announcements will appear here.',
      _ => 'You have no alerts right now.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(
              Icons.notifications_none,
              size: 42,
              color: BrandColors.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No alerts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.dashboard,
    required this.onLogout,
    required this.onManageVerification,
  });

  final Map<String, dynamic> dashboard;
  final VoidCallback onLogout;
  final ValueChanged<int>? onManageVerification;

  String _statusFor(List<String> keys) {
    for (final key in keys) {
      final value = dashboard[key];

      if (value is bool) {
        return value ? 'COMPLETED' : 'PENDING';
      }

      final status = value?.toString().trim().toUpperCase();
      if (status == null || status.isEmpty) continue;

      if (status.contains('APPROV') ||
          status.contains('COMPLETE') ||
          status.contains('VERIFIED') ||
          status == 'SUBMITTED' ||
          status == 'ACTIVE') {
        return 'COMPLETED';
      }

      if (status.contains('REJECT') ||
          status.contains('CHANGE') ||
          status.contains('FAILED')) {
        return 'ACTION REQUIRED';
      }

      return 'PENDING';
    }

    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (dashboard['partnerName'] ?? dashboard['name'] ?? 'Partner').toString();
    final email =
        (dashboard['email'] ?? dashboard['partnerEmail'] ?? '').toString();
    final phone =
        (dashboard['phone'] ?? dashboard['partnerPhone'] ?? '').toString();

    final identityStatus = _statusFor(const [
      'identityStatus',
      'kycStatus',
      'identityVerified',
      'kycCompleted',
    ]);

    final addressStatus = _statusFor(const [
      'addressStatus',
      'addressVerificationStatus',
      'addressVerified',
      'addressCompleted',
    ]);

    final payoutStatus = _statusFor(const [
      'payoutStatus',
      'bankStatus',
      'bankVerificationStatus',
      'payoutCompleted',
    ]);

    final applicationStatus = _statusFor(const [
      'applicationStatus',
      'approvalStatus',
      'accountStatus',
      'readyForJobs',
      'accountEligible',
    ]);

    final completedCount = [
      identityStatus,
      addressStatus,
      payoutStatus,
      applicationStatus,
    ].where((status) => status == 'COMPLETED').length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'View your partner details and verification progress.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: const TextStyle(color: BrandColors.muted),
                          ),
                        ],
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            phone,
                            style: const TextStyle(color: BrandColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verification status',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completedCount/4 completed',
                style: const TextStyle(
                  color: BrandColors.lime,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: completedCount / 4,
            minHeight: 8,
            backgroundColor: BrandColors.muted.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          _ProfileVerificationCard(
            step: 1,
            icon: Icons.badge_outlined,
            title: 'Identity verification',
            onboardingTabIndex: 1,
            onManage: onManageVerification,
            status: identityStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 2,
            icon: Icons.location_on_outlined,
            title: 'Address verification',
            onboardingTabIndex: 2,
            onManage: onManageVerification,
            status: addressStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 3,
            icon: Icons.account_balance_outlined,
            title: 'Payout details',
            onboardingTabIndex: 3,
            onManage: onManageVerification,
            status: payoutStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 4,
            icon: Icons.verified_user_outlined,
            title: 'Application approval',
            onboardingTabIndex: 4,
            onManage: onManageVerification,
            status: applicationStatus,
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.support_agent_outlined),
                  title: Text('Support'),
                  subtitle: Text('Get help with your partner account'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileVerificationCard extends StatefulWidget {
  const _ProfileVerificationCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.status,
    required this.onboardingTabIndex,
    required this.onManage,
  });

  final int step;
  final IconData icon;
  final String title;
  final String status;
  final int onboardingTabIndex;
  final ValueChanged<int>? onManage;

  @override
  State<_ProfileVerificationCard> createState() =>
      _ProfileVerificationCardState();
}

class _ProfileVerificationCardState extends State<_ProfileVerificationCard> {
  bool _expanded = false;

  bool get _completed => widget.status == 'COMPLETED';
  bool get _actionRequired => widget.status == 'ACTION REQUIRED';

  String get _description {
    switch (widget.title) {
      case 'Identity verification':
        return _completed
            ? 'Identity documents have been submitted and verified.'
            : _actionRequired
                ? 'Your identity documents need correction.'
                : 'Identity verification is still pending.';
      case 'Address verification':
        return _completed
            ? 'Your address and address proof are verified.'
            : _actionRequired
                ? 'Your address details need correction.'
                : 'Address verification is pending.';
      case 'Payout details':
        return _completed
            ? 'Your bank account or UPI payout details are ready.'
            : _actionRequired
                ? 'Your payout details need correction.'
                : 'Payout verification is pending.';
      case 'Application approval':
        return _completed
            ? 'Your Partner application is approved.'
            : _actionRequired
                ? 'Your application needs changes before approval.'
                : 'Your application is waiting for admin approval.';
      default:
        return 'Verification details are unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _completed
        ? BrandColors.lime
        : _actionRequired
            ? Colors.redAccent
            : Colors.amber;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.18),
              foregroundColor: accent,
              child: _completed
                  ? const Icon(Icons.check)
                  : Text(
                      '${widget.step}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.status,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _description,
                          style: const TextStyle(
                            color: BrandColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onManage == null
                          ? null
                          : () => widget.onManage!(
                                widget.onboardingTabIndex,
                              ),
                      icon: Icon(
                        _completed
                            ? Icons.visibility_outlined
                            : Icons.edit_document,
                      ),
                      label: Text(
                        _completed
                            ? 'View details'
                            : widget.title == 'Application approval'
                                ? 'View application status'
                                : 'Complete verification',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onOpen,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final service = booking['service'] ??
        booking['serviceName'] ??
        booking['title'] ??
        'Service booking';
    final location = booking['location'] ??
        booking['address'] ??
        booking['area'] ??
        'Location unavailable';
    final status = (booking['status'] ?? 'NEW').toString().replaceAll('_', ' ');
    final time = booking['scheduledFor'] ??
        booking['time'] ??
        booking['scheduledTime'] ??
        'Time unavailable';
    final payout =
        booking['payout'] ?? booking['estimatedPayout'] ?? booking['amount'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  status,
                  style: const TextStyle(
                    color: BrandColors.lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              location.toString(),
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _InlineDetail(
                  icon: Icons.schedule_outlined,
                  text: time.toString(),
                ),
                if (payout != null)
                  _InlineDetail(
                    icon: Icons.currency_rupee,
                    text: payout.toString(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onOpen,
              child: const Text('Open booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDetail extends StatelessWidget {
  const _InlineDetail({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: BrandColors.muted),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
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

class IncomingBookingRequestScreen extends StatefulWidget {
  const IncomingBookingRequestScreen({
    super.key,
    required this.api,
    required this.session,
    required this.booking,
  });

  final ApiClient api;
  final Session session;
  final Map<String, dynamic> booking;

  @override
  State<IncomingBookingRequestScreen> createState() =>
      _IncomingBookingRequestScreenState();
}

class _IncomingBookingRequestScreenState
    extends State<IncomingBookingRequestScreen> {
  Timer? _timer;
  late int _secondsRemaining;
  bool _submitting = false;
  bool _finished = false;
  String? _resultTitle;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();

    final expirySeconds = widget.booking['expiresInSeconds'] ??
        widget.booking['expirySeconds'] ??
        30;

    _secondsRemaining = expirySeconds is num
        ? expirySeconds.toInt().clamp(1, 300)
        : int.tryParse(expirySeconds.toString())?.clamp(1, 300) ?? 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;

      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _finished = true;
          _resultTitle = 'Request expired';
          _resultMessage = 'This booking request is no longer available.';
        });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _bookingId =>
      (widget.booking['id'] ?? widget.booking['bookingId'] ?? '').toString();

  String get _customerName => (widget.booking['customerFirstName'] ??
          widget.booking['customerName'] ??
          widget.booking['customer'] ??
          'Customer')
      .toString()
      .split(' ')
      .first;

  String get _service => (widget.booking['service'] ??
          widget.booking['serviceName'] ??
          widget.booking['title'] ??
          'Service booking')
      .toString();

  String get _dateTime => (widget.booking['scheduledFor'] ??
          widget.booking['dateTime'] ??
          widget.booking['time'] ??
          'Time unavailable')
      .toString();

  String get _approximateLocation => (widget.booking['approximateLocation'] ??
          widget.booking['area'] ??
          widget.booking['location'] ??
          'Approximate location unavailable')
      .toString();

  String get _distance => (widget.booking['distance'] ??
          widget.booking['distanceKm'] ??
          'Distance unavailable')
      .toString();

  String get _duration => (widget.booking['duration'] ??
          widget.booking['estimatedDuration'] ??
          'Duration unavailable')
      .toString();

  String get _earnings {
    final value = widget.booking['estimatedEarnings'] ??
        widget.booking['estimatedPayout'] ??
        widget.booking['payout'] ??
        widget.booking['amount'];

    if (value == null) return '₹0';

    final text = value.toString().trim();
    return text.startsWith('₹') ? text : '₹$text';
  }

  String get _timerText {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _accept() async {
    if (_finished || _secondsRemaining <= 0 || _submitting) return;

    if (_bookingId.isEmpty) {
      _showResult(
        'Acceptance failed',
        'The booking identifier is missing.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.api.post(
        '/bookings/$_bookingId/accept',
        const <String, dynamic>{},
        token: widget.session.token,
      );

      _timer?.cancel();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AcceptedBookingDetailsScreen(
            api: widget.api,
            session: widget.session,
            bookingId: _bookingId,
            initialBooking: widget.booking,
          ),
        ),
      );
    } on ApiException catch (error) {
      _showResult('Acceptance failed', error.message);
    } catch (_) {
      _showResult(
        'Acceptance failed',
        'The booking could not be accepted. It may have expired or been assigned to another partner.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    if (_finished || _submitting) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _RejectBookingSheet(),
    );

    if (reason == null) return;

    if (_bookingId.isEmpty) {
      _showResult('Rejection failed', 'The booking identifier is missing.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.api.post(
        '/bookings/$_bookingId/reject',
        {
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
        token: widget.session.token,
      );

      _timer?.cancel();

      if (!mounted) return;
      setState(() {
        _finished = true;
        _resultTitle = 'Booking rejected';
        _resultMessage = 'The request was dismissed successfully.';
      });
    } on ApiException catch (error) {
      _showResult('Rejection failed', error.message);
    } catch (_) {
      _showResult(
        'Rejection failed',
        'The booking request could not be rejected.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showResult(String title, String message) {
    if (!mounted) return;

    setState(() {
      _resultTitle = title;
      _resultMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expired = _secondsRemaining <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking request'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'New booking request',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: expired
                        ? Colors.redAccent.withValues(alpha: 0.14)
                        : BrandColors.lime.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _timerText,
                    style: TextStyle(
                      color: expired ? Colors.redAccent : BrandColors.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Review the job details before accepting.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _RequestDetailRow(
                      icon: Icons.person_outline,
                      label: 'Customer',
                      value: _customerName,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.cleaning_services_outlined,
                      label: 'Service',
                      value: _service,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.schedule_outlined,
                      label: 'Date and time',
                      value: _dateTime,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Approximate location',
                      value: _approximateLocation,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.route_outlined,
                      label: 'Distance',
                      value: _distance,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.timelapse_outlined,
                      label: 'Estimated duration',
                      value: _duration,
                    ),
                    const Divider(height: 24),
                    _RequestDetailRow(
                      icon: Icons.currency_rupee_outlined,
                      label: 'Estimated earnings',
                      value: _earnings,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Customer privacy protected'),
                subtitle: Text(
                  'The exact customer address remains hidden until you accept the booking.',
                ),
              ),
            ),
            if (_resultTitle != null) ...[
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: Icon(
                    _resultTitle == 'Booking assigned'
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: _resultTitle == 'Booking assigned'
                        ? BrandColors.lime
                        : Colors.orangeAccent,
                  ),
                  title: Text(_resultTitle!),
                  subtitle: Text(_resultMessage ?? ''),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!_finished)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _reject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: expired || _submitting ? null : _accept,
                      child: Text(
                        _submitting ? 'Please wait...' : 'Accept',
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _resultTitle == 'Booking assigned' ? 'accepted' : 'rejected',
                ),
                child: const Text('Return to dashboard'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestDetailRow extends StatelessWidget {
  const _RequestDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BrandColors.lime),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: BrandColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: emphasized ? 18 : 15,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RejectBookingSheet extends StatefulWidget {
  const _RejectBookingSheet();

  @override
  State<_RejectBookingSheet> createState() => _RejectBookingSheetState();
}

class _RejectBookingSheetState extends State<_RejectBookingSheet> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reject booking',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You may optionally tell us why you cannot take this request.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'For example: too far away',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _reasonController.text,
                  ),
                  child: const Text('Reject request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AcceptedBookingDetailsScreen extends StatefulWidget {
  const AcceptedBookingDetailsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.bookingId,
    required this.initialBooking,
  });

  final ApiClient api;
  final Session session;
  final String bookingId;
  final Map<String, dynamic> initialBooking;

  @override
  State<AcceptedBookingDetailsScreen> createState() =>
      _AcceptedBookingDetailsScreenState();
}

class _AcceptedBookingDetailsScreenState
    extends State<AcceptedBookingDetailsScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;
  bool _contactLoading = false;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.initialBooking);
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.api.get(
        '/bookings/${widget.bookingId}',
        token: widget.session.token,
      );

      if (!mounted) return;

      if (result is Map) {
        setState(() {
          _booking = {
            ...?_booking,
            ...Map<String, dynamic>.from(result),
          };
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Latest booking details are unavailable. Showing the last available information.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(List<String> keys, {String fallback = 'Not available'}) {
    final data = _booking ?? const <String, dynamic>{};

    for (final key in keys) {
      final value = data[key];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }

    return fallback;
  }

  String get _customerName => _text(
        const ['customerFirstName', 'customerName', 'customer'],
        fallback: 'Customer',
      );

  String get _service => _text(
        const ['service', 'serviceName', 'title'],
        fallback: 'Service booking',
      );

  String get _address => _text(
        const ['customerAddress', 'exactAddress', 'address'],
        fallback: 'Address unavailable',
      );

  String get _scheduledFor => _text(
        const ['scheduledFor', 'dateTime', 'scheduledTime', 'time'],
      );

  String get _duration => _text(
        const ['duration', 'estimatedDuration'],
      );

  String get _distance => _text(
        const ['distance', 'distanceKm'],
      );

  String get _earnings {
    final data = _booking ?? const <String, dynamic>{};
    final value = data['estimatedEarnings'] ??
        data['estimatedPayout'] ??
        data['payout'] ??
        data['amount'];

    if (value == null) return '₹0';

    final text = value.toString().trim();
    return text.startsWith('₹') ? text : '₹$text';
  }

  List<String> get _serviceChecklist {
    final data = _booking ?? const <String, dynamic>{};
    final raw = data['serviceChecklist'] ?? data['checklist'] ?? data['tasks'];

    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return (item['label'] ?? item['name'] ?? item['title'] ?? '')
                  .toString()
                  .trim();
            }
            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }

  Future<void> _startJourney() async {
    _showMessage('Journey started. Navigation is ready.');
  }

  Future<void> _navigate() async {
    if (_address == 'Address unavailable') {
      _showMessage('Customer address is currently unavailable.');
      return;
    }

    _showMessage('Opening navigation to $_address');
  }

  Future<void> _contactCustomer() async {
    if (_contactLoading) return;

    setState(() => _contactLoading = true);

    try {
      final result = await widget.api.post(
        '/bookings/${widget.bookingId}/contact-token',
        const <String, dynamic>{},
        token: widget.session.token,
      );

      if (!mounted) return;

      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : const <String, dynamic>{};

      final channel =
          (data['channel'] ?? data['type'] ?? 'masked contact').toString();

      _showMessage('Secure $channel is ready.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Secure customer contact is currently unavailable.');
    } finally {
      if (mounted) setState(() => _contactLoading = false);
    }
  }

  Future<void> _cancelBooking() async {
    final request = await showModalBottomSheet<_CancellationRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CancelAcceptedBookingSheet(),
    );

    if (!mounted) return;
    if (request == null || _cancelling) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm cancellation'),
            content: Text(
              request.penaltyMessage.isEmpty
                  ? 'Cancellation rules may apply. Do you want to cancel this booking?'
                  : request.penaltyMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep booking'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm cancellation'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _cancelling = true);

    try {
      await widget.api.post(
        '/bookings/${widget.bookingId}/cancel',
        {
          if (request.reason.trim().isNotEmpty) 'reason': request.reason.trim(),
        },
        token: widget.session.token,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking cancelled'),
          content: const Text(
            'The booking has been cancelled successfully.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop('cancelled');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('The booking could not be cancelled.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklist = _serviceChecklist;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accepted booking'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadBooking,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh booking',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const _AcceptedConfirmationCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.cloud_off_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text('Limited offline details'),
                  subtitle: Text(_error!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _AcceptedSectionCard(
              title: 'Customer details',
              icon: Icons.person_pin_circle_outlined,
              children: [
                _AcceptedDetailRow(
                  label: 'Customer',
                  value: _customerName,
                ),
                const Divider(height: 24),
                _AcceptedDetailRow(
                  label: 'Exact address',
                  value: _address,
                ),
                if (_distance != 'Not available') ...[
                  const Divider(height: 24),
                  _AcceptedDetailRow(
                    label: 'Distance',
                    value: _distance,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _AcceptedSectionCard(
              title: 'Service details',
              icon: Icons.cleaning_services_outlined,
              children: [
                _AcceptedDetailRow(
                  label: 'Service',
                  value: _service,
                ),
                if (checklist.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Service checklist',
                      style: TextStyle(
                        color: BrandColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  ...checklist.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 19,
                            color: BrandColors.lime,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(task)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _AcceptedSectionCard(
              title: 'Booking summary',
              icon: Icons.receipt_long_outlined,
              children: [
                _AcceptedDetailRow(
                  label: 'Date and time',
                  value: _scheduledFor,
                ),
                const Divider(height: 24),
                _AcceptedDetailRow(
                  label: 'Estimated duration',
                  value: _duration,
                ),
                const Divider(height: 24),
                _AcceptedDetailRow(
                  label: 'Your estimated earnings',
                  value: _earnings,
                  emphasized: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startJourney,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start journey'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _navigate,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _contactLoading ? null : _contactCustomer,
              icon: const Icon(Icons.phone_in_talk_outlined),
              label: Text(
                _contactLoading
                    ? 'Preparing secure contact...'
                    : 'Contact customer',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showMessage(
                'Contacting MaidItQuick support.',
              ),
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Contact support'),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _cancelling ? null : _cancelBooking,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                _cancelling ? 'Cancelling...' : 'Cancel booking',
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _AcceptedConfirmationCard extends StatelessWidget {
  const _AcceptedConfirmationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: BrandColors.lime,
              foregroundColor: BrandColors.evergreen,
              child: Icon(Icons.check, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              'Booking assigned',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'You now have the allowed customer and journey details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedSectionCard extends StatelessWidget {
  const _AcceptedSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: BrandColors.lime),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AcceptedDetailRow extends StatelessWidget {
  const _AcceptedDetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: BrandColors.muted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 18 : 14,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CancellationRequest {
  const _CancellationRequest({
    required this.reason,
    required this.penaltyMessage,
  });

  final String reason;
  final String penaltyMessage;
}

class _CancelAcceptedBookingSheet extends StatefulWidget {
  const _CancelAcceptedBookingSheet();

  @override
  State<_CancelAcceptedBookingSheet> createState() =>
      _CancelAcceptedBookingSheetState();
}

class _CancelAcceptedBookingSheetState
    extends State<_CancelAcceptedBookingSheet> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';

  static const reasons = [
    'Personal emergency',
    'Unable to reach customer location',
    'Schedule conflict',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason =
        _selectedReason == 'Other' ? _reasonController.text : _selectedReason;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cancel booking',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cancellation rules or a penalty may apply. Review them before confirming.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason.isEmpty ? null : _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Cancellation reason',
            ),
            items: reasons
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _selectedReason = value ?? '');
            },
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tell us why',
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_outlined,
                color: Colors.orangeAccent,
              ),
              title: Text('Cancellation warning'),
              subtitle: Text(
                'Repeated or late cancellations may affect account standing or incentives.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep booking'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: reason.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            _CancellationRequest(
                              reason: reason.trim(),
                              penaltyMessage:
                                  'Repeated or late cancellations may affect account standing or incentives. Confirm cancellation?',
                            ),
                          ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

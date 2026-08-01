import 'package:flutter/material.dart';

import '../../../core/brand_theme.dart';

class PartnerBookingsTab extends StatefulWidget {
  const PartnerBookingsTab({
    super.key,
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
  State<PartnerBookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<PartnerBookingsTab> {
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
                      child: PartnerBookingCard(
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

class PartnerBookingCard extends StatelessWidget {
  const PartnerBookingCard({
    super.key,
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


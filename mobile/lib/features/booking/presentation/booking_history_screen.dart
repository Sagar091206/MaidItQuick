import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'booking_details_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({
    super.key,
    required this.api,
    required this.session,
  });

  final ApiClient api;
  final Session session;

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  late final BookingRepository _repository;
  List<CustomerBooking> _bookings = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  static const _filters = [
    ('ALL', 'All'),
    ('REQUESTED', 'Requested'),
    ('ASSIGNED', 'Awaiting acceptance'),
    ('ACCEPTED', 'Accepted'),
    ('ON_THE_WAY', 'On the way'),
    ('ARRIVED', 'Arrived'),
    ('IN_PROGRESS', 'In progress'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = BookingRepository(widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await _repository.list(widget.session.token);
      if (mounted) setState(() => _bookings = bookings);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your bookings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CustomerBooking> get _visible {
    if (_filter == 'ALL') return _bookings;
    return _bookings.where((booking) => booking.status == _filter).toList();
  }

  Future<void> _openDetails(CustomerBooking booking) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          api: widget.api,
          session: widget.session,
          bookingId: booking.id,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 42, color: theme.colorScheme.primary),
                          const SizedBox(height: 14),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final filter = _filters[index];
                              final selected = filter.$1 == _filter;
                              return FilterChip(
                                label: Text(filter.$2),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _filter = filter.$1),
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: _visible.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(20),
                                  children: const [
                                    _EmptyBookings(),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(20),
                                  itemCount: _visible.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) => _BookingTile(
                                    booking: _visible[index],
                                    onTap: () => _openDetails(_visible[index]),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.onTap});

  final CustomerBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: context.brandCard,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MIQ-${booking.id}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (booking.needsPayment) ...[
                    StatusPill(
                      status: 'Payment pending',
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _StatusPill(status: booking.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                booking.service,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                booking.address,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.brandMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _BookingMeta(
                    icon: Icons.schedule_outlined,
                    label: _displayDate(booking.scheduledFor),
                  ),
                  _BookingMeta(
                    icon: Icons.timer_outlined,
                    label: '${booking.durationMinutes} min',
                  ),
                  if (booking.workerHasAccepted &&
                      booking.worker != 'Unassigned')
                    _BookingMeta(
                      icon: Icons.person_pin_circle_outlined,
                      label: booking.worker,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          customerBookingStatusLabel(status),
          style: TextStyle(
            color: scheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BookingMeta extends StatelessWidget {
  const _BookingMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.brandMuted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.brandMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.history, color: context.scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No bookings here',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Book a cleaning service from the dashboard and it will appear here.',
                    style: TextStyle(color: context.brandMuted, height: 1.3),
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

String _displayDate(String iso) {
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return iso;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}, $hour:$minute';
}

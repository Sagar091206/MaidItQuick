import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_dashboard_repository.dart';

class MvpHomeScreen extends StatefulWidget {
  const MvpHomeScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    required this.onOpenSettings,
    required this.onBookService,
    required this.onOpenBookings,
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onBookService;
  final VoidCallback onOpenBookings;

  @override
  State<MvpHomeScreen> createState() => _MvpHomeScreenState();
}

class _MvpHomeScreenState extends State<MvpHomeScreen> {
  late final CustomerDashboardRepository _repository;
  final _search = TextEditingController();
  CustomerDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = CustomerDashboardRepository(widget.api);
    _search.addListener(() => setState(() {}));
    _loadDashboard();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _repository.fetch(widget.session.token);
      if (mounted) setState(() => _dashboard = dashboard);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your dashboard.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBookingFlow() async {
    await widget.onBookService();
    if (mounted) await _loadDashboard();
  }

  List<ServiceCategory> get _filteredServices {
    final dashboard = _dashboard;
    if (dashboard == null) return const [];
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return dashboard.services;
    return dashboard.services
        .where((service) => service.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaidItQuick'),
        actions: [
          IconButton(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile and settings',
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _DashboardError(message: _error!, onRetry: _loadDashboard)
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: _DashboardBody(
                      dashboard: _dashboard!,
                      search: _search,
                      services: _filteredServices,
                      onBookService: _openBookingFlow,
                      onOpenBookings: widget.onOpenBookings,
                    ),
                  ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.search,
    required this.services,
    required this.onBookService,
    required this.onOpenBookings,
  });

  final CustomerDashboard dashboard;
  final TextEditingController search;
  final List<ServiceCategory> services;
  final VoidCallback onBookService;
  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context) {
    final name =
        dashboard.welcomeName.trim().isEmpty ? 'there' : dashboard.welcomeName;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final addressCardHeight = 132.0 * (textScale < 1 ? 1 : textScale);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Text(
          'Hello, $name',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Book cleaning services, track active work and reuse your saved addresses.',
          style: TextStyle(color: BrandColors.muted, height: 1.35),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onBookService,
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Book a service'),
        ),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'Saved addresses',
          actionLabel: dashboard.addresses.isEmpty ? 'Add address' : 'Manage',
          onAction: onBookService,
        ),
        const SizedBox(height: 10),
        if (dashboard.addresses.isEmpty)
          _EmptyState(
            icon: Icons.location_off_outlined,
            title: 'No saved addresses yet',
            body: 'Add one before booking a cleaning service.',
          )
        else
          SizedBox(
            height: addressCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dashboard.addresses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _AddressCard(address: dashboard.addresses[index]),
            ),
          ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Services'),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Search cleaning services',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        if (services.isEmpty)
          _EmptyState(
            icon: Icons.search_off,
            title: 'No services found',
            body: 'Try bathroom, kitchen, bedroom, balcony or living room.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) => _ServiceCard(
              service: services[index],
              onTap: onBookService,
            ),
          ),
        const SizedBox(height: 24),
        if (dashboard.activeBooking != null) ...[
          _SectionHeader(
            title: 'Active booking',
            actionLabel: 'View history',
            onAction: onOpenBookings,
          ),
          const SizedBox(height: 10),
          _BookingCard(
            booking: dashboard.activeBooking!,
            highlighted: true,
          ),
          const SizedBox(height: 24),
        ],
        _SectionHeader(
          title: 'Recent booking',
          actionLabel: 'View history',
          onAction: onOpenBookings,
        ),
        const SizedBox(height: 10),
        if (dashboard.recentBooking == null)
          _EmptyState(
            icon: Icons.history,
            title: 'No completed bookings yet',
            body: 'Your latest completed service will appear here.',
          )
        else
          _BookingCard(booking: dashboard.recentBooking!),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final Map<String, dynamic> address;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: BrandColors.lime, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address['label']?.toString() ?? 'Address',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (address['defaultAddress'] == true)
                    const Icon(Icons.check_circle,
                        color: BrandColors.lime, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address['address']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BrandColors.muted, height: 1.25),
              ),
              const Spacer(),
              Text(
                address['pinCode']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final ServiceCategory service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cleaning_services_outlined,
                  color: BrandColors.lime),
              const Spacer(),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(service.priceLabel,
                  style: const TextStyle(color: BrandColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.highlighted = false});

  final DashboardBooking booking;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  highlighted
                      ? Icons.radio_button_checked
                      : Icons.check_circle_outline,
                  color: BrandColors.lime,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MIQ-${booking.id}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(booking.service,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(booking.address,
                style: const TextStyle(color: BrandColors.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _BookingMeta(
                  icon: Icons.schedule_outlined,
                  label: booking.scheduledFor,
                ),
                _BookingMeta(
                  icon: Icons.timer_outlined,
                  label: '${booking.durationMinutes} min',
                ),
                _BookingMeta(
                  icon: Icons.person_pin_circle_outlined,
                  label: booking.worker,
                ),
              ],
            ),
          ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BrandColors.lime.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.replaceAll('_', ' '),
          style: const TextStyle(
            color: BrandColors.lime,
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
        Icon(icon, size: 16, color: BrandColors.muted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: BrandColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: BrandColors.lime),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          color: BrandColors.muted, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: BrandColors.lime, size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

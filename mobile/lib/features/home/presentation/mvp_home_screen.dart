import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/service_catalog_repository.dart';
import '../../booking/presentation/booking_details_screen.dart';
import '../../services/presentation/service_details_screen.dart';
import '../data/customer_dashboard_repository.dart';

/// Premium home dashboard for the signed-in customer.
///
/// Renders the greeting, default service address (with a switcher), the
/// service catalog grouped by category chips, an active-booking hero card
/// when one exists, and full loading / empty / error / offline states.
class MvpHomeScreen extends StatefulWidget {
  const MvpHomeScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    required this.onOpenSettings,
    required this.onBookService,
    required this.onOpenBookings,
    required this.onInstantMaid,
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onBookService;
  final VoidCallback onOpenBookings;
  final VoidCallback onInstantMaid;

  @override
  State<MvpHomeScreen> createState() => _MvpHomeScreenState();
}

class _MvpHomeScreenState extends State<MvpHomeScreen> {
  late final CustomerDashboardRepository _repository;
  final _search = TextEditingController();
  CustomerDashboard? _dashboard;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  String _category = 'All';
  bool _switchingAddress = false;

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
    if (_dashboard == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _offline = false);
    }
    try {
      final dashboard = await _repository.fetch(widget.session.token);
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _error = null;
          _offline = false;
        });
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        setState(() {
          if (_dashboard == null) _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _offline = true;
          if (_dashboard == null) _error = 'Could not reach MaidItQuick.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBookingFlow() async {
    await widget.onBookService();
    if (mounted) await _loadDashboard();
  }

  Future<void> _openServiceDetails(ServiceCategory service) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ServiceDetailsScreen(
          api: widget.api,
          session: widget.session,
          serviceId: service.id,
          initialService: CatalogService(
            id: service.id,
            name: service.name,
            pricePaise: service.pricePaise,
            enabled: true,
            emoji: service.emoji,
            description: service.description,
            defaultDurationMinutes: service.defaultDurationMinutes,
          ),
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openTrackBooking(DashboardBooking booking) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          api: widget.api,
          session: widget.session,
          bookingId: booking.id,
        ),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  /// Lets the customer pick another saved address as the default one.
  Future<void> _changeAddress() async {
    final dashboard = _dashboard;
    if (dashboard == null || dashboard.addresses.isEmpty) {
      await _openBookingFlow();
      return;
    }
    final picked = await showModalBottomSheet<DashboardAddress>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AddressSwitcherSheet(
        addresses: dashboard.addresses,
        selected: dashboard.defaultAddress,
      ),
    );
    if (picked == null || !mounted) return;
    final current = dashboard.defaultAddress;
    if (current != null && current.id == picked.id) return;
    setState(() => _switchingAddress = true);
    try {
      final saved =
          await _repository.setDefaultAddress(widget.session.token, picked.id);
      if (!mounted) return;
      setState(() {
        final updated = _dashboard;
        if (updated != null) {
          _dashboard = CustomerDashboard(
            welcomeName: updated.welcomeName,
            addresses: updated.addresses
                .map((a) => a.id == saved.id ? saved : a)
                .toList(),
            services: updated.services,
            activeBooking: updated.activeBooking,
            recentBooking: updated.recentBooking,
          );
        }
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _switchingAddress = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<ServiceCategory> get _filteredServices {
    final dashboard = _dashboard;
    if (dashboard == null) return const [];
    final query = _search.text.trim().toLowerCase();
    return dashboard.services.where((service) {
      final matchesQuery =
          query.isEmpty || service.name.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'All' || categoryOf(service) == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Category chips are derived from the first word of each service name
  /// (e.g. "Bathroom Cleaning" -> "Bathroom").
  List<String> get _categories {
    final dashboard = _dashboard;
    if (dashboard == null) return const ['All'];
    final seen = <String>{};
    for (final service in dashboard.services) {
      seen.add(categoryOf(service));
    }
    return ['All', ...seen];
  }

  static String categoryOf(ServiceCategory service) {
    final first = service.name.trim().split(RegExp(r'\s+')).first;
    if (first.isEmpty) return 'Other';
    return '${first[0].toUpperCase()}${first.substring(1)}';
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
        child: _loading && _dashboard == null
            ? const SkeletonListView(itemCount: 5)
            : Column(
                children: [
                  if (_offline)
                    OfflineBanner(
                        onRetry: _dashboard == null ? _loadDashboard : null),
                  Expanded(
                    child: _error != null && _dashboard == null
                        ? ErrorStateView(
                            message: _error!, onRetry: _loadDashboard)
                        : RefreshIndicator(
                            onRefresh: _loadDashboard,
                            child: _DashboardBody(
                              dashboard: _dashboard!,
                              search: _search,
                              categories: _categories,
                              category: _category,
                              services: _filteredServices,
                              switchingAddress: _switchingAddress,
                              onCategorySelected: (category) =>
                                  setState(() => _category = category),
                              onBookService: _openBookingFlow,
                              onChangeAddress: _changeAddress,
                              onOpenServiceDetails: _openServiceDetails,
                              onTrackBooking: _openTrackBooking,
                              onOpenBookings: widget.onOpenBookings,
                              onInstantMaid: widget.onInstantMaid,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.search,
    required this.categories,
    required this.category,
    required this.services,
    required this.switchingAddress,
    required this.onCategorySelected,
    required this.onBookService,
    required this.onChangeAddress,
    required this.onOpenServiceDetails,
    required this.onTrackBooking,
    required this.onOpenBookings,
    required this.onInstantMaid,
  });

  final CustomerDashboard dashboard;
  final TextEditingController search;
  final List<String> categories;
  final String category;
  final List<ServiceCategory> services;
  final bool switchingAddress;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onBookService;
  final VoidCallback onChangeAddress;
  final ValueChanged<ServiceCategory> onOpenServiceDetails;
  final ValueChanged<DashboardBooking> onTrackBooking;
  final VoidCallback onOpenBookings;
  final VoidCallback onInstantMaid;

  @override
  Widget build(BuildContext context) {
    final name =
        dashboard.welcomeName.trim().isEmpty ? 'there' : dashboard.welcomeName;
    final defaultAddress = dashboard.defaultAddress;
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
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: onBookService,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Schedule'))),
          const SizedBox(width: 10),
          Expanded(
              child: FilledButton.icon(
                  onPressed: onInstantMaid,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Instant')))
        ]),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Service address'),
        const SizedBox(height: 10),
        if (defaultAddress == null)
          EmptyStateView(
            icon: Icons.location_off_outlined,
            title: 'No saved address yet',
            message: 'Add your service address to start booking.',
            actionLabel: 'Add address',
            onAction: onChangeAddress,
          )
        else
          _DefaultAddressCard(
            address: defaultAddress,
            busy: switchingAddress,
            onChange: onChangeAddress,
          ),
        const SizedBox(height: 24),
        if (dashboard.activeBooking != null) ...[
          SectionHeader(
            title: 'Active booking',
            actionLabel: 'View history',
            onAction: onOpenBookings,
          ),
          const SizedBox(height: 10),
          _ActiveBookingHero(
            booking: dashboard.activeBooking!,
            onTrack: () => onTrackBooking(dashboard.activeBooking!),
          ),
          const SizedBox(height: 24),
        ],
        const SectionHeader(title: 'Services'),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Search cleaning services',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in categories) ...[
                ChoiceChip(
                  label: Text(item),
                  selected: item == category,
                  onSelected: (_) => onCategorySelected(item),
                ),
                if (item != categories.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (services.isEmpty)
          EmptyStateView(
            icon: dashboard.services.isEmpty
                ? Icons.cleaning_services_outlined
                : Icons.search_off,
            title: dashboard.services.isEmpty
                ? 'No services available yet'
                : 'No matching services',
            message: dashboard.services.isEmpty
                ? 'New cleaning services for your area are on the way.'
                : 'Try another search or category.',
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
              onTap: () => onOpenServiceDetails(services[index]),
            ),
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Recent booking',
          actionLabel: 'View history',
          onAction: onOpenBookings,
        ),
        const SizedBox(height: 10),
        if (dashboard.recentBooking == null)
          const EmptyStateView(
            icon: Icons.history,
            title: 'No completed bookings yet',
            message: 'Your latest completed service will appear here.',
          )
        else
          _BookingCard(booking: dashboard.recentBooking!),
      ],
    );
  }
}

/// Default service address card with a "Change" action that opens the
/// address switcher bottom sheet.
class _DefaultAddressCard extends StatelessWidget {
  const _DefaultAddressCard({
    required this.address,
    required this.busy,
    required this.onChange,
  });

  final DashboardAddress address;
  final bool busy;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onChange,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              address.address,
              style: TextStyle(color: context.brandMuted, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              'PIN ${address.pinCode}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the saved addresses for switching the default.
class _AddressSwitcherSheet extends StatelessWidget {
  const _AddressSwitcherSheet({
    required this.addresses,
    required this.selected,
  });

  final List<DashboardAddress> addresses;
  final DashboardAddress? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Change service address',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'The selected address becomes your default booking address.',
              style: TextStyle(color: BrandColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          for (final address in addresses)
            ListTile(
              leading: Icon(
                address.id == selected?.id
                    ? Icons.check_circle
                    : Icons.location_on_outlined,
                color: address.id == selected?.id
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(address.label),
              subtitle: Text(
                '${address.address}\nPIN ${address.pinCode}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(address),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final ServiceCategory service;
  final VoidCallback onTap;

  static String emojiFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('bath')) return '\u{1F6C1}';
    if (n.contains('kitchen')) return '\u{1F373}';
    if (n.contains('bed')) return '\u{1F6CF}';
    if (n.contains('balcony')) return '\u{1FAB4}';
    if (n.contains('living')) return '\u{1F6CB}';
    if (n.contains('deep') || n.contains('full')) return '\u2728';
    if (n.contains('dust')) return '\u{1F9F9}';
    if (n.contains('window')) return '\u{1FA9F}';
    return '\u{1F9FD}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emojiFor(service.name),
                style: const TextStyle(fontSize: 34),
              ),
              const Spacer(),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                service.priceLabel,
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active booking hero card with a Track action.
class _ActiveBookingHero extends StatelessWidget {
  const _ActiveBookingHero({required this.booking, required this.onTrack});

  final DashboardBooking booking;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radio_button_checked, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    booking.service,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${formatDateTime(booking.scheduledFor)} \\u00B7 ${booking.durationMinutes} min',
              style: TextStyle(color: context.brandMuted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.track_changes_outlined),
              label: const Text('Track booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final DashboardBooking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MIQ-${booking.id}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.service,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              booking.address,
              style: TextStyle(color: context.brandMuted),
            ),
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
          constraints: const BoxConstraints(maxWidth: 210),
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

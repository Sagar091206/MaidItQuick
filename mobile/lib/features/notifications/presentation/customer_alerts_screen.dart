import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/booking_details_screen.dart';
import '../data/notification_repository.dart';

class CustomerAlertsScreen extends StatefulWidget {
  const CustomerAlertsScreen(
      {super.key, required this.api, required this.session});
  final ApiClient api;
  final Session session;

  @override
  State<CustomerAlertsScreen> createState() => _CustomerAlertsScreenState();
}

class _CustomerAlertsScreenState extends State<CustomerAlertsScreen> {
  late final NotificationRepository _repository =
      NotificationRepository(widget.api);
  List<CustomerNotification> _items = const [];
  bool _loading = true;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller =
        Timer.periodic(const Duration(seconds: 12), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _repository.list(widget.session.token);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (!quiet && mounted) setState(() => _error = error.message);
    } catch (_) {
      if (!quiet && mounted) setState(() => _error = 'Could not load alerts.');
    } finally {
      if (!quiet && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(CustomerNotification item) async {
    if (!item.read) {
      try {
        final updated =
            await _repository.markRead(widget.session.token, item.id);
        if (mounted) {
          setState(() => _items = _items
              .map((current) => current.id == updated.id ? updated : current)
              .toList());
        }
      } catch (_) {}
    }
    if (item.bookingId != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(
                api: widget.api,
                session: widget.session,
                bookingId: item.bookingId!,
              )));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alerts'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh alerts'),
        ]),
        body: SafeArea(
            child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const SkeletonListView(itemCount: 5)
              : _error != null
                  ? ErrorStateView(message: _error!, onRetry: _load)
                  : _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 100),
                          EmptyStateView(
                              icon: Icons.notifications_none,
                              title: 'No alerts yet',
                              message:
                                  'Booking updates and service OTPs will appear here.')
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) => _AlertCard(
                              item: _items[index],
                              onTap: () => _open(_items[index])),
                        ),
        )),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item, required this.onTap});
  final CustomerNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otp = item.otp;
    return Card(
      color: item.containsOtp ? context.scheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: item.containsOtp
                    ? BrandColors.lime
                    : context.scheme.surfaceContainerHighest,
                child: Icon(
                    item.containsOtp
                        ? Icons.pin_outlined
                        : Icons.notifications_outlined,
                    color: item.containsOtp ? BrandColors.evergreen : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (!item.read)
                        const Icon(Icons.circle,
                            size: 9, color: BrandColors.lime)
                    ]),
                    const SizedBox(height: 5),
                    Text(item.message,
                        style:
                            TextStyle(color: context.brandMuted, height: 1.35)),
                    if (otp != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Text(otp,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5)),
                        const Spacer(),
                        IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: otp));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('OTP copied')));
                            },
                            icon: const Icon(Icons.copy_outlined),
                            tooltip: 'Copy OTP'),
                      ]),
                    ],
                    if (item.bookingId != null) ...[
                      const SizedBox(height: 8),
                      Text('Open booking MIQ-${item.bookingId}',
                          style: TextStyle(
                              color: context.scheme.primary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ])),
            ])),
      ),
    );
  }
}

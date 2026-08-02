import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'booking_details_screen.dart';

/// Shown right after payment succeeds. Explains the automatic partner
/// assignment and hands the customer to the tracking screen.
class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.api,
    required this.session,
    required this.bookingId,
    this.paymentReference = '',
  });

  final ApiClient api;
  final Session session;
  final int bookingId;
  final String paymentReference;

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  CustomerBooking? _booking;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await BookingRepository(widget.api)
          .fetch(widget.session.token, widget.bookingId);
      if (mounted) setState(() => _booking = booking);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your booking.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _track() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          api: widget.api,
          session: widget.session,
          bookingId: widget.bookingId,
        ),
      ),
    );
  }

  void _done() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking confirmed'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 3)
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 24),
                      const Center(child: SuccessCheck()),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Booking MIQ-${booking!.id} confirmed',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          booking.isPaid
                              ? 'Payment received. A verified partner is being assigned automatically.'
                              : 'Complete the payment so a partner can be assigned.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: context.brandMuted, height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _NextStepCard(
                        icon: Icons.group_outlined,
                        title: '1 · Partner assignment',
                        body:
                            'A verified partner who covers your tasks and PIN is matched automatically. You cannot choose a partner.',
                      ),
                      _NextStepCard(
                        icon: Icons.pin_outlined,
                        title: '2 · Start OTP',
                        body:
                            'When the partner arrives, they ask for your 6-digit start OTP from the Alerts tab. Share it only after they arrive.',
                      ),
                      _NextStepCard(
                        icon: Icons.cleaning_services_outlined,
                        title: '3 · Service & end OTP',
                        body:
                            'The service runs for the booked duration with your supplies. A completion OTP ends the service.',
                      ),
                      const SizedBox(height: 22),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _Row(
                                  label: 'Tasks',
                                  value: booking.services.isEmpty
                                      ? booking.service
                                      : booking.services.join(', ')),
                              _Row(label: 'Address', value: booking.address),
                              _Row(
                                  label: 'Schedule',
                                  value: formatDateTime(booking.scheduledFor)),
                              _Row(
                                  label: 'Duration',
                                  value: '${booking.durationMinutes} minutes'),
                              if (booking.isPaid)
                                _Row(
                                  label: 'Amount paid',
                                  value:
                                      formatPaise(booking.paymentAmountPaise),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _track,
                        icon: const Icon(Icons.track_changes_outlined),
                        label: const Text('Track booking'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _done,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Back to dashboard'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      style:
                          TextStyle(color: context.brandMuted, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: context.brandMuted)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'payment_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.bookingId,
  });

  final ApiClient api;
  final Session session;
  final int bookingId;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late final BookingRepository _repository;
  final _cancelReasonController = TextEditingController();
  final _ratingController = TextEditingController();
  CustomerBooking? _booking;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = BookingRepository(widget.api);
    _load();
  }

  @override
  void dispose() {
    _cancelReasonController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking =
          await _repository.fetch(widget.session.token, widget.bookingId);
      if (mounted) setState(() => _booking = booking);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this booking.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final booking = _booking;
    if (booking == null || !booking.canCancel) return;
    final reason = await _promptCancelReason();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated =
          await _repository.cancel(widget.session.token, booking.id, reason.trim());
      if (mounted) {
        setState(() => _booking = updated);
        _showMessage('Booking cancelled');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptCancelReason() async {
    _cancelReasonController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: TextField(
          controller: _cancelReasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'Tell us why you are cancelling',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_cancelReasonController.text),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _reschedule() async {
    final booking = _booking;
    if (booking == null || !booking.canReschedule) return;
    final scheduled = await _pickSchedule();
    if (scheduled == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _repository.reschedule(
          widget.session.token, booking.id, scheduled.toIso8601String());
      if (mounted) {
        setState(() => _booking = updated);
        _showMessage('Booking rescheduled');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DateTime?> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return null;
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        final slots = _timeSlots(date);
        return SimpleDialog(
          title: Text('Pick a time on ${_shortDate(date)}'),
          children: [
            for (final slot in slots)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(slot),
                child: Row(
                  children: [
                    Icon(Icons.schedule_outlined, color: context.scheme.primary),
                    const SizedBox(width: 12),
                    Text(_slotLabel(slot)),
                  ],
                ),
              ),
          ],
        );
      },
    );
    return selected;
  }

  List<DateTime> _timeSlots(DateTime date) {
    final now = DateTime.now();
    return [8, 10, 12, 14, 16, 18]
        .map((hour) => DateTime(date.year, date.month, date.day, hour))
        .where((slot) => slot.isAfter(now))
        .toList();
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _slotLabel(DateTime slot) {
    final hour = slot.hour.toString().padLeft(2, '0');
    return '$hour:00';
  }

  Future<void> _pay() async {
    final booking = _booking;
    if (booking == null || !booking.needsPayment) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          api: widget.api,
          session: widget.session,
          booking: booking,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _rate() async {
    final booking = _booking;
    if (booking == null || !booking.canRate) return;
    final rating = await _promptRating();
    if (rating == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _repository.rate(
          widget.session.token, booking.id, rating.$1, rating.$2);
      if (mounted) {
        setState(() => _booking = updated);
        _showMessage('Thanks for rating this service!');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(int, String)?> _promptRating() async {
    var stars = 5;
    _ratingController.clear();
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => stars = i),
                      icon: Icon(
                        i <= stars ? Icons.star : Icons.star_border,
                        color: i <= stars
                            ? const Color(0xFFFFB300)
                            : context.brandMuted,
                        size: 32,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ratingController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'How was your experience?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((stars, _ratingController.text.trim())),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking ${_booking == null ? '' : 'MIQ-${_booking!.id}'}'),
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
                : _DetailsBody(
                    booking: _booking!,
                    busy: _busy,
                    onPay: _booking!.needsPayment ? _pay : null,
                    onCancel: _booking!.canCancel ? _cancel : null,
                    onReschedule: _booking!.canReschedule ? _reschedule : null,
                    onRate: _booking!.canRate ? _rate : null,
                  ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.booking,
    required this.busy,
    required this.onPay,
    required this.onCancel,
    required this.onReschedule,
    required this.onRate,
  });

  final CustomerBooking booking;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serviceLines =
        booking.services.isEmpty ? [booking.service] : booking.services;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusBanner(status: booking.status),
        if (booking.cancellationReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Reason: ${booking.cancellationReason}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        _Timeline(events: booking.events),
        const SizedBox(height: 8),
        _Section(
          title: 'Services',
          icon: Icons.cleaning_services_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in serviceLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(line,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Schedule',
          icon: Icons.event_available_outlined,
          child: Text(_displayDate(booking.scheduledFor)),
        ),
        _Section(
          title: 'Address',
          icon: Icons.location_on_outlined,
          child: Text('${booking.address}\nPIN ${booking.pinCode}'),
        ),
        _Section(
          title: 'Worker',
          icon: Icons.person_pin_circle_outlined,
          child: Text(booking.worker),
        ),
        _Section(
          title: 'Details',
          icon: Icons.receipt_long_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Duration', value: '${booking.durationMinutes} min'),
              _DetailRow(label: 'Service option', value: booking.optionLabel),
              if (booking.promoCode.isNotEmpty)
                _DetailRow(label: 'Promo code', value: booking.promoCode),
              if (booking.discountPaise > 0)
                _DetailRow(
                    label: 'Discount',
                    value: '₹${(booking.discountPaise / 100).toStringAsFixed(0)}'),
              if (booking.specialInstructions.isNotEmpty)
                _DetailRow(
                    label: 'Instructions', value: booking.specialInstructions),
            ],
          ),
        ),
        _Section(
          title: 'Payment',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                  label: 'Payment status',
                  value: _paymentLabel(booking.paymentStatus)),
              if (booking.paymentAmountPaise > 0)
                _DetailRow(
                    label: 'Amount',
                    value: formatPaise(booking.paymentAmountPaise)),
              if (booking.isPaid && booking.paymentMethod.isNotEmpty)
                _DetailRow(label: 'Paid with', value: booking.paymentMethod),
              if (booking.isPaid && booking.paidAt != null)
                _DetailRow(
                    label: 'Paid on', value: _displayDate(booking.paidAt!)),
            ],
          ),
        ),
        if (booking.rating > 0)
          _Section(
            title: 'Your rating',
            icon: Icons.star_outline,
            child: Text('${booking.rating} / 5 stars'),
          ),
        const SizedBox(height: 18),
        if (onPay != null) ...[
          FilledButton.icon(
            onPressed: busy ? null : onPay,
            icon: const Icon(Icons.lock_outline),
            label: Text(
                'Pay ${formatPaise(booking.paymentAmountPaise)} to proceed'),
          ),
          const SizedBox(height: 10),
        ],
        if (onRate != null) ...[
          FilledButton.icon(
            onPressed: busy ? null : onRate,
            icon: const Icon(Icons.star_outline),
            label: const Text('Rate this service'),
          ),
          const SizedBox(height: 10),
        ],
        if (onReschedule != null) ...[
          OutlinedButton.icon(
            onPressed: busy ? null : onReschedule,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Reschedule booking'),
          ),
          const SizedBox(height: 10),
        ],
        if (onCancel != null)
          OutlinedButton.icon(
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            label: const Text('Cancel booking'),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<BookingEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Booking timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            color: context.brandCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++) ...[
                    _TimelineRow(
                      event: events[i],
                      isLast: i == events.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final BookingEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final active = event.status == 'CANCELLED'
        ? theme.colorScheme.error
        : scheme.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(Icons.circle, size: 12, color: active),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: scheme.primary.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.note,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _displayDate(event.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.brandMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.radio_button_checked, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusHint(status),
                    style: TextStyle(
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.7)),
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

String _statusHint(String status) {
  switch (status) {
    case 'REQUESTED':
      return 'Complete the payment — a partner is assigned automatically after payment.';
    case 'ASSIGNED':
      return 'Payment received. A partner has been assigned to your booking.';
    case 'ACCEPTED':
      return 'Your partner has accepted the job.';
    case 'ON_THE_WAY':
      return 'Your partner is travelling to the service location.';
    case 'ARRIVED':
      return 'Your partner has arrived at the service location.';
    case 'IN_PROGRESS':
      return 'The service is in progress at your location.';
    case 'COMPLETED':
      return 'This service has been completed.';
    case 'CANCELLED':
      return 'This booking was cancelled.';
    default:
      return '';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            color: context.brandCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: context.brandMuted, height: 1.35),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium),
          ),
        ],
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

String _paymentLabel(String paymentStatus) {
  switch (paymentStatus) {
    case 'PAID':
      return 'Paid';
    case 'PENDING':
      return 'Payment processing';
    case 'FAILED':
      return 'Payment failed — retry';
    case 'REFUNDED':
      return 'Refunded';
    default:
      return 'Payment pending';
  }
}

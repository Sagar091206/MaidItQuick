import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/partner_repository.dart';
import 'accepted_booking_details_screen.dart';

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

  late final PartnerRepository _partnerRepository =
      PartnerRepository(widget.api);

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

  bool get _isInstantRequest =>
      widget.booking['isInstantRequest'] == true ||
      widget.booking['status']?.toString() == 'SEARCHING' ||
      widget.booking['optionLabel']?.toString() == 'Instant Maid';

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

  String get _duration {
    final value = widget.booking['duration'] ??
        widget.booking['estimatedDuration'] ??
        widget.booking['durationMinutes'];
    if (value == null) return 'Duration unavailable';
    final text = value.toString().trim();
    return widget.booking['durationMinutes'] != null &&
            widget.booking['duration'] == null &&
            widget.booking['estimatedDuration'] == null
        ? '$text min'
        : text;
  }

  String get _earnings {
    final paise = widget.booking['paymentAmountPaise'];
    if (paise is num) return '₹${(paise / 100).toStringAsFixed(0)}';
    final value = widget.booking['estimatedEarnings'] ??
        widget.booking['estimatedPayout'] ??
        widget.booking['payout'] ??
        widget.booking['amount'];
    if (value == null) return '₹0';
    return '₹${value.toString().trim().replaceFirst('₹', '')}';
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
      final data = _isInstantRequest
          ? await _partnerRepository.acceptInstantBooking(
              widget.session.token,
              _bookingId,
            )
          : await _partnerRepository.acceptBooking(
              widget.session.token,
              _bookingId,
            );

      _timer?.cancel();

      if (!mounted) return;

      // Prefer the server-confirmed booking reference over the value carried
      // by the request card.
      final confirmedId =
          (data['id'] ?? data['bookingId'] ?? _bookingId).toString();

      if (confirmedId.isEmpty) {
        _showResult(
          'Acceptance failed',
          'The server did not return a booking reference.',
        );
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AcceptedBookingDetailsScreen(
            api: widget.api,
            session: widget.session,
            bookingId: confirmedId,
            initialBooking: {...widget.booking, ...data},
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
      if (_isInstantRequest) {
        await _partnerRepository.rejectInstantBooking(
          widget.session.token,
          _bookingId,
        );

        _timer?.cancel();

        if (!mounted) return;
        setState(() {
          _finished = true;
          _resultTitle = 'Request declined';
          _resultMessage = 'The instant request was dismissed successfully.';
        });
        return;
      }
      await _partnerRepository.rejectBooking(
        widget.session.token,
        _bookingId,
        reason: reason,
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

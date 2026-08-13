import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../support/presentation/support_screen.dart';
import '../data/partner_repository.dart';

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
  bool _journeyStarting = false;
  bool _stageUpdating = false;
  String? _error;

  late final PartnerRepository _partnerRepository =
      PartnerRepository(widget.api);

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
      final result = await _partnerRepository.fetchBooking(
        widget.session.token,
        widget.bookingId,
      );

      if (!mounted) return;

      setState(() {
        _booking = {
          ...?_booking,
          ...result,
        };
      });
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

  String get _duration {
    final minutes = _booking?['durationMinutes'];
    if (minutes != null) return '$minutes min';
    return _text(const ['duration', 'estimatedDuration']);
  }

  String get _distance => _text(
        const ['distance', 'distanceKm'],
      );

  String get _earnings {
    final data = _booking ?? const <String, dynamic>{};
    final paise = data['paymentAmountPaise'];
    if (paise is num) return '₹${(paise / 100).toStringAsFixed(0)}';
    final value = data['estimatedEarnings'] ??
        data['estimatedPayout'] ??
        data['payout'] ??
        data['amount'];
    if (value == null) return '₹0';
    return '₹${value.toString().trim().replaceFirst('₹', '')}';
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
    if (_journeyStarting) return;

    setState(() => _journeyStarting = true);

    try {
      final result = await _partnerRepository.startJourney(
        widget.session.token,
        widget.bookingId,
      );

      if (!mounted) return;

      setState(() {
        _booking = {
          ...?_booking,
          ...result,
        };
      });

      _showMessage('You are on the way to the customer.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not start the journey right now.');
    } finally {
      if (mounted) setState(() => _journeyStarting = false);
    }
  }

  String get _status =>
      (_booking?['status'] ?? 'ASSIGNED').toString().trim().toUpperCase();

  Future<void> _updateStage(Future<Map<String, dynamic>> Function() request,
      String successMessage) async {
    if (_stageUpdating) return;
    setState(() => _stageUpdating = true);
    try {
      final result = await request();
      if (!mounted) return;
      setState(() => _booking = {...?_booking, ...result});
      _showMessage(successMessage);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('This booking update could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _stageUpdating = false);
    }
  }

  Future<void> _verifyOtp({required bool completing}) async {
    if (_stageUpdating) return;
    setState(() => _stageUpdating = true);
    try {
      if (completing) {
        await _partnerRepository.requestCompletionCode(
            widget.session.token, widget.bookingId);
      } else {
        await _partnerRepository.requestStartCode(
            widget.session.token, widget.bookingId);
      }
      if (!mounted) return;
      final controller = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(completing ? 'Complete service' : 'Start service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(completing
                  ? 'A completion OTP was sent to the customer. Enter the six-digit code they share with you.'
                  : 'A start OTP was sent to the customer. Enter the six-digit code they share with you.'),
              const SizedBox(height: 14),
              TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '6-digit OTP')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Verify')),
          ],
        ),
      );
      controller.dispose();
      if (code == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
        _showMessage('Enter the six-digit OTP shared by the customer.');
        return;
      }
      final result = completing
          ? await _partnerRepository.completeService(
              widget.session.token, widget.bookingId, code)
          : await _partnerRepository.startService(
              widget.session.token, widget.bookingId, code);
      if (!mounted) return;
      setState(() => _booking = {...?_booking, ...result});
      _showMessage(completing
          ? 'Service completed successfully.'
          : 'Service has started.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('OTP verification is unavailable right now.');
    } finally {
      if (mounted) setState(() => _stageUpdating = false);
    }
  }

  Widget _serviceAction() {
    final busy = _journeyStarting || _stageUpdating;
    switch (_status) {
      case 'ASSIGNED':
      case 'ACCEPTED':
        return FilledButton.icon(
            onPressed: busy ? null : _startJourney,
            icon: const Icon(Icons.directions_car_filled_outlined),
            label: Text(
                _journeyStarting ? 'Starting journey...' : 'Start journey'));
      case 'ON_THE_WAY':
        return FilledButton.icon(
            onPressed: busy
                ? null
                : () => _updateStage(
                    () => _partnerRepository.markArrived(
                        widget.session.token, widget.bookingId),
                    'Arrival marked. Ask the customer for the start OTP.'),
            icon: const Icon(Icons.location_on_outlined),
            label: Text(_stageUpdating ? 'Saving...' : 'Mark as arrived'));
      case 'ARRIVED':
        return FilledButton.icon(
            onPressed: busy ? null : () => _verifyOtp(completing: false),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(
                _stageUpdating ? 'Please wait...' : 'Start service with OTP'));
      case 'IN_PROGRESS':
        return FilledButton.icon(
            onPressed: busy ? null : () => _verifyOtp(completing: true),
            icon: const Icon(Icons.verified_outlined),
            label: Text(_stageUpdating
                ? 'Please wait...'
                : 'Complete service with OTP'));
      case 'COMPLETED':
        return FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('Service completed'));
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _navigate() async {
    if (_address == 'Address unavailable') {
      _showMessage('Customer address is currently unavailable.');
      return;
    }

    final pin = _text(
      const ['customerPinCode', 'pinCode', 'pincode'],
      fallback: '',
    );
    final parts = <String>[_address];
    if (pin.trim().isNotEmpty) parts.add(pin.trim());
    final query = Uri.encodeComponent(parts.join(', '));

    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final uri = Uri.parse(
      isApple
          ? 'https://maps.apple.com/?q=$query'
          : 'https://www.google.com/maps/search/?api=1&query=$query',
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showMessage('Could not open maps for this address.');
      }
    } catch (_) {
      _showMessage('Could not open navigation right now.');
    }
  }

  Future<void> _openSupport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SupportScreen(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  Future<void> _contactCustomer() async {
    if (_contactLoading) return;

    setState(() => _contactLoading = true);

    try {
      final data = await _partnerRepository.requestContactToken(
        widget.session.token,
        widget.bookingId,
      );

      if (!mounted) return;

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
      await _partnerRepository.cancelBooking(
        widget.session.token,
        widget.bookingId,
        reason: request.reason,
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
            _serviceAction(),
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
              onPressed: _openSupport,
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

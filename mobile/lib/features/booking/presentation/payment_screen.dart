import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'booking_confirmation_screen.dart';

/// Payment step: method selection → mock gateway → confirmation screen.
/// Runs against the mock gateway (simulated delay; cards ending in 0000 are
/// declined). A successful payment routes to BookingConfirmationScreen, which
/// owns the receipt and the next-steps copy.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.api,
    required this.session,
    required this.booking,
  });

  final ApiClient api;
  final Session session;
  final CustomerBooking booking;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static final _upiPattern = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  String _method = 'UPI';
  final _upi = TextEditingController();
  final _card = TextEditingController();
  final _bank = TextEditingController();

  bool _processing = false;
  String _processingStep = 'Contacting the gateway…';

  @override
  void initState() {
    super.initState();
    if (widget.booking.isPaid) {
      // Already paid (e.g. reopened after a partial flow) — go to confirmation.
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToConfirmation());
    }
  }

  @override
  void dispose() {
    _upi.dispose();
    _card.dispose();
    _bank.dispose();
    super.dispose();
  }

  String? _validate() {
    final upi = _upi.text.trim();
    final card = _card.text.replaceAll(' ', '').trim();
    final bank = _bank.text.trim();
    switch (_method) {
      case 'UPI':
        if (upi.isEmpty) return 'Enter your UPI ID.';
        if (!_upiPattern.hasMatch(upi)) {
          return 'Enter a valid UPI ID, e.g. yourname@upi.';
        }
      case 'CARD':
        if (card.isEmpty) return 'Enter your card number.';
        if (card.length < 13 || card.length > 16) {
          return 'Enter a valid 13–16 digit card number.';
        }
      case 'NETBANKING':
        if (bank.isEmpty) return 'Choose your bank.';
    }
    return null;
  }

  Future<void> _pay() async {
    final validation = _validate();
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    setState(() {
      _processing = true;
      _processingStep = 'Contacting the gateway…';
    });
    try {
      final repo = BookingRepository(widget.api);
      final intent =
          await repo.createPayIntent(widget.session.token, widget.booking.id, _method);
      if (!mounted) return;
      setState(() => _processingStep = 'Confirming your payment…');
      final card = _card.text.replaceAll(' ', '').trim();
      final card4 = card.length >= 4 ? card.substring(card.length - 4) : '';
      final record = await repo.pay(
        widget.session.token,
        bookingId: widget.booking.id,
        intentId: intent.intentId,
        method: _method,
        upiId: _upi.text.trim(),
        cardLast4: card4,
        bankName: _bank.text.trim(),
      );
      if (!mounted) return;
      if (record.isPaid) {
        _goToConfirmation(reference: record.reference);
      } else {
        _showMessage('The payment was not completed. Please try again.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      await _handlePayError(error);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handlePayError(ApiException error) async {
    switch (error.statusCode) {
      case 402:
        _showMessage(error.message);
      case 409:
        // The intent was already processed — re-check the booking in case
        // an earlier attempt actually went through.
        try {
          final fresh = await BookingRepository(widget.api)
              .fetch(widget.session.token, widget.booking.id);
          if (!mounted) return;
          if (fresh.isPaid) {
            _goToConfirmation(reference: fresh.paidAt ?? '');
            return;
          }
        } catch (_) {}
        _showMessage(error.message);
      case 410:
        await _showExpiredDialog();
      default:
        _showMessage(error.message);
    }
  }

  Future<void> _showExpiredDialog() async {
    final cancelIt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment session expired'),
        content: const Text(
            'This booking could not be paid within the allowed window. '
            'You can cancel it and create a new booking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel & book again'),
          ),
        ],
      ),
    );
    if (cancelIt != true || !mounted) return;
    try {
      await BookingRepository(widget.api).cancel(
          widget.session.token, widget.booking.id, 'Payment session expired');
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _goToConfirmation({String reference = ''}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          api: widget.api,
          session: widget.session,
          bookingId: widget.booking.id,
          paymentReference: reference,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(child: _buildForm()),
    );
  }

  Widget _buildForm() {
    final booking = widget.booking;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: context.brandCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        color: BrandColors.lime),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('MIQ-${booking.id}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(booking.service,
                    style: TextStyle(color: context.brandMuted)),
                const SizedBox(height: 8),
                Divider(color: context.scheme.outlineVariant),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount to pay',
                        style: TextStyle(color: context.brandMuted)),
                    Text(formatPaise(booking.paymentAmountPaise),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Pay with',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) => setState(() => _method = value!),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'UPI',
                title: const Text('UPI'),
                subtitle: const Text('GPay, PhonePe, Paytm'),
                activeColor: BrandColors.lime,
              ),
              RadioListTile<String>(
                value: 'CARD',
                title: const Text('Card'),
                subtitle: const Text('Debit / credit (mock gateway)'),
                activeColor: BrandColors.lime,
              ),
              RadioListTile<String>(
                value: 'NETBANKING',
                title: const Text('Net banking'),
                activeColor: BrandColors.lime,
              ),
            ],
          ),
        ),
        if (_method == 'UPI') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _upi,
            keyboardType: TextInputType.emailAddress,
            enabled: !_processing,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'yourname@upi',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
        ],
        if (_method == 'CARD') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _card,
            keyboardType: TextInputType.number,
            enabled: !_processing,
            maxLength: 19,
            inputFormatters: [_CardNumberFormatter()],
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: 'Ending 0000 simulates a declined payment',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
        ],
        if (_method == 'NETBANKING') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _bank,
            enabled: !_processing,
            decoration: const InputDecoration(
              labelText: 'Bank',
              hintText: 'HDFC, SBI, ICICI …',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _processing ? null : _pay,
          icon: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: Text(_processing
              ? _processingStep
              : 'Pay ${formatPaise(booking.paymentAmountPaise)}'),
        ),
        const SizedBox(height: 10),
        const Text(
          'This is a simulated payment gateway for the MVP. No real money moves.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: BrandColors.muted),
        ),
      ],
    );
  }
}

/// Groups card digits into blocks of four as the user types.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

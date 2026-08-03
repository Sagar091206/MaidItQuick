import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/presentation/payment_screen.dart';
import '../../booking/data/customer_addresses_repository.dart';
import '../data/instant_booking_repository.dart';

class InstantMaidScreen extends StatefulWidget {
  const InstantMaidScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.address});
  final ApiClient api;
  final Session session;
  final CustomerAddress? address;
  @override
  State<InstantMaidScreen> createState() => _InstantMaidScreenState();
}

class _InstantMaidScreenState extends State<InstantMaidScreen> {
  int _duration = 60;
  bool _submitting = false;
  final _notes = TextEditingController();
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  int get _amount => 29900 * _duration ~/ 60;
  Future<void> _continue() async {
    final address = widget.address;
    if (address == null) {
      _message('Choose a service address before requesting an instant maid.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final booking = await InstantBookingRepository(widget.api).create(
          widget.session.token,
          addressId: address.id,
          durationMinutes: _duration,
          instructions: _notes.text.trim());
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentScreen(
              api: widget.api, session: widget.session, booking: booking)));
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Instant Maid')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Get a maid now',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Basic Home Cleaning \u00B7 matched after payment',
            style: TextStyle(color: BrandColors.muted)),
        const SizedBox(height: 18),
        Card(
            child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                    widget.address?.label ?? 'No service address selected'),
                subtitle: Text(widget.address?.address ??
                    'Return home to select or add an address.'))),
        const SizedBox(height: 18),
        const Text('Choose duration',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [60, 90, 120, 150, 180, 210, 240]
                .map((minutes) => ChoiceChip(
                    label: Text(minutes < 120
                        ? '$minutes min'
                        : '${minutes ~/ 60}${minutes % 60 == 0 ? ' hr' : ' hr 30 min'}'),
                    selected: _duration == minutes,
                    onSelected: (_) => setState(() => _duration = minutes)))
                .toList()),
        const SizedBox(height: 18),
        TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                hintText: 'Please focus on the kitchen and living room.')),
        const SizedBox(height: 20),
        Card(
            child: ListTile(
                title: const Text('Estimated price'),
                subtitle: const Text('\u20B9299 per hour'),
                trailing: Text('\u20B9${_amount ~/ 100}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 8),
        const Text(
            'Estimated arrival: about 15\u201330 minutes after a partner accepts.',
            style: TextStyle(color: BrandColors.muted)),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _submitting ? null : _continue,
            icon: const Icon(Icons.lock_outline),
            label: Text(
                _submitting ? 'Creating request...' : 'Continue to payment')),
      ])));
}

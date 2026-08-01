import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/data/customer_addresses_repository.dart';
import '../../booking/data/service_catalog_repository.dart';

class CustomerJourneyScreen extends StatefulWidget {
  const CustomerJourneyScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.onLogout,
      this.onEditProfile});

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;
  final VoidCallback? onEditProfile;

  @override
  State<CustomerJourneyScreen> createState() => _CustomerJourneyScreenState();
}

class _CustomerJourneyScreenState extends State<CustomerJourneyScreen> {
  final _label = TextEditingController(text: 'Home');
  final _houseNumber = TextEditingController();
  final _building = TextEditingController();
  final _street = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'Maharashtra');
  final _pin = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _addresses = [];
  final Set<String> _selectedServices = {};
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _availability;
  final _specialInstructions = TextEditingController();
  DateTime _scheduled = DateTime.now().add(const Duration(hours: 1));
  bool _loading = true;
  bool _savingAddress = false;
  bool _booking = false;
  bool _reviewing = false;
  Map<String, dynamic>? _confirmedBooking;
  int? _editingAddressId;

  static const List<TimeOfDay> _timeSlots = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _label.dispose();
    _houseNumber.dispose();
    _building.dispose();
    _street.dispose();
    _area.dispose();
    _landmark.dispose();
    _city.dispose();
    _state.dispose();
    _pin.dispose();
    _specialInstructions.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final catalog = ServiceCatalogRepository(widget.api);
      final addresses = CustomerAddressesRepository(widget.api);
      final data = await Future.wait<dynamic>([
        catalog.listServices(),
        addresses.list(widget.session.token),
      ]);
      if (!mounted) return;
      final services = List<Map<String, dynamic>>.from(data[0] as List);
      final savedAddresses = List<CustomerAddress>.from(data[1] as List)
          .map((entry) => entry.toMap())
          .toList();
      setState(() {
        _services = services;
        _addresses = savedAddresses;
        _selectedAddress = _defaultAddress(savedAddresses);
        if (services.isNotEmpty) {
          _selectedServices.add(services.first['name']?.toString() ?? '');
          _selectedServices.remove('');
        }
        if (_selectedAddress != null) {
          _pin.text = _selectedAddress!['pinCode']?.toString() ?? '';
        }
        _scheduled = _nextAvailableSlot();
      });
      if (_pin.text.length == 6) await _checkAvailability();
      await _recomputeDuration();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
          'Could not load services. Confirm that the API server is running.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _defaultAddress(List<Map<String, dynamic>> addresses) {
    if (addresses.isEmpty) return null;
    for (final address in addresses) {
      if (address['defaultAddress'] == true) return address;
    }
    return addresses.first;
  }

  List<String> get _selectedServiceNames => _selectedServices.toList()..sort();

  int _duration = 0;

  Future<void> _recomputeDuration() async {
    final selected = _selectedServiceNames;
    if (selected.isEmpty) {
      if (mounted) setState(() => _duration = 0);
      return;
    }
    try {
      final minutes = await ServiceCatalogRepository(widget.api)
          .calculateDuration(selected);
      if (mounted) setState(() => _duration = minutes);
    } on ApiException {
      if (mounted) setState(() => _duration = selected.length * 60);
    }
  }

  DateTime _slotDateTime(DateTime date, TimeOfDay slot) =>
      DateTime(date.year, date.month, date.day, slot.hour, slot.minute);

  bool _slotAvailable(TimeOfDay slot) =>
      _slotDateTime(_scheduled, slot).isAfter(DateTime.now()) &&
      _availability?['status'] != 'NOT_AVAILABLE';

  DateTime _nextAvailableSlot() {
    final now = DateTime.now();
    for (final slot in _timeSlots) {
      final candidate = _slotDateTime(now, slot);
      if (candidate.isAfter(now.add(const Duration(minutes: 30)))) {
        return candidate;
      }
    }
    final tomorrow = now.add(const Duration(days: 1));
    final slot = _timeSlots.first;
    return _slotDateTime(tomorrow, slot);
  }

  void _toggleService(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      if (_selectedServices.contains(name)) {
        if (_selectedServices.length == 1) {
          _showMessage('Choose at least one service.');
          return;
        }
        _selectedServices.remove(name);
      } else {
        _selectedServices.add(name);
      }
    });
    _recomputeDuration();
  }

  CustomerAddressDraft _addressPayload({required bool defaultAddress}) =>
      CustomerAddressDraft(
        label: _label.text.trim(),
        houseNumber: _houseNumber.text.trim(),
        building: _building.text.trim(),
        street: _street.text.trim(),
        area: _area.text.trim(),
        landmark: _landmark.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        pinCode: _pin.text.trim(),
        defaultAddress: defaultAddress,
      );

  bool get _addressFormValid =>
      _label.text.trim().isNotEmpty &&
      _houseNumber.text.trim().isNotEmpty &&
      _street.text.trim().isNotEmpty &&
      _area.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _state.text.trim().isNotEmpty &&
      _validPin;

  Future<void> _saveAddress({bool makeDefault = false}) async {
    if (!_addressFormValid) {
      _showMessage(
          'Enter nickname, house number, street, area, city, state and PIN code.');
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final payload = _addressPayload(
          defaultAddress:
              makeDefault || _addresses.isEmpty || _editingAddressId == null);
      final repository = CustomerAddressesRepository(widget.api);
      final saved = _editingAddressId == null
          ? await repository.create(widget.session.token, payload)
          : await repository.update(
              widget.session.token, _editingAddressId!, payload);
      if (!mounted) return;
      setState(() {
        if (_editingAddressId == null) {
          _addresses = [
            saved.toMap(),
            ..._addresses.where((item) => item['id'] != saved.id)
          ];
        } else {
          _addresses = _addresses
              .map((item) => item['id'] == saved.id ? saved.toMap() : item)
              .toList();
        }
        _selectedAddress = saved.toMap();
        _editingAddressId = null;
        _availability = null;
      });
      await _checkAvailability();
      _showMessage('Address saved.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _setDefaultAddress(Map<String, dynamic> address) async {
    try {
      final saved = await CustomerAddressesRepository(widget.api)
          .setDefault(widget.session.token, (address['id'] as num).toInt());
      if (!mounted) return;
      setState(() {
        _addresses = _addresses
            .map((item) => {
                  ...item,
                  'defaultAddress': item['id'] == saved.id,
                })
            .toList();
        _selectedAddress = saved.toMap();
        _pin.text = saved.pinCode;
      });
      await _checkAvailability();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('Delete ${address['label']} from your saved addresses?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CustomerAddressesRepository(widget.api)
          .delete(widget.session.token, (address['id'] as num).toInt());
      if (!mounted) return;
      setState(() {
        _addresses =
            _addresses.where((item) => item['id'] != address['id']).toList();
        if (_selectedAddress?['id'] == address['id']) {
          _selectedAddress = _defaultAddress(_addresses);
        }
      });
      _showMessage('Address removed.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _startEditingAddress(Map<String, dynamic> address) {
    setState(() {
      _editingAddressId = (address['id'] as num?)?.toInt();
      _label.text = address['label']?.toString() ?? '';
      _houseNumber.text = address['houseNumber']?.toString() ?? '';
      _building.text = address['building']?.toString() ?? '';
      _street.text = address['street']?.toString() ?? '';
      _area.text = address['area']?.toString() ?? '';
      _landmark.text = address['landmark']?.toString() ?? '';
      _city.text = address['city']?.toString() ?? '';
      _state.text = address['state']?.toString() ?? 'Maharashtra';
      _pin.text = address['pinCode']?.toString() ?? '';
      _selectedAddress = address;
      _availability = null;
    });
  }

  void _resetAddressForm() {
    setState(() {
      _editingAddressId = null;
      _label.text = 'Home';
      _houseNumber.clear();
      _building.clear();
      _street.clear();
      _area.clear();
      _landmark.clear();
      _city.clear();
      _state.text = 'Maharashtra';
      _pin.clear();
      _availability = null;
    });
  }

  bool get _validPin => RegExp(r'^\d{6}$').hasMatch(_pin.text.trim());

  Future<void> _checkAvailability() async {
    if (!_validPin) {
      _showMessage('Enter a six-digit PIN code.');
      return;
    }
    try {
      final result = await ServiceCatalogRepository(widget.api)
          .checkAvailability(_pin.text.trim());
      if (mounted) {
        setState(() => _availability = {
              'status': result.status,
              'label': result.label,
              'message': result.message,
              if (result.etaMinutes != null) 'etaMinutes': result.etaMinutes,
            });
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final currentSlot = TimeOfDay.fromDateTime(_scheduled);
    final slot =
        _timeSlots.contains(currentSlot) ? currentSlot : _timeSlots.first;
    setState(() {
      _scheduled = _slotDateTime(date, slot);
      if (!_scheduled.isAfter(DateTime.now())) {
        _scheduled = _nextAvailableSlot();
      }
    });
  }

  void _selectSlot(TimeOfDay slot) {
    if (!_slotAvailable(slot)) return;
    setState(() => _scheduled = _slotDateTime(_scheduled, slot));
  }

  bool _validateBookingDraft() {
    final address = _selectedAddress;
    if (address == null) {
      _showMessage('Save or choose a service address first.');
      return false;
    }
    if (_selectedServices.isEmpty) {
      _showMessage('Choose at least one cleaning service.');
      return false;
    }
    if (_availability?['status'] == 'NOT_AVAILABLE') {
      _showMessage('MaidItQuick is not available at this PIN code yet.');
      return false;
    }
    if (!_scheduled.isAfter(DateTime.now())) {
      _showMessage('Choose an upcoming time slot.');
      return false;
    }
    return true;
  }

  void _reviewBooking() {
    if (!_validateBookingDraft()) return;
    setState(() => _reviewing = true);
  }

  void _editBooking() => setState(() => _reviewing = false);

  Future<void> _book() async {
    final address = _selectedAddress;
    if (!_validateBookingDraft() || address == null) return;
    setState(() => _booking = true);
    try {
      final selected = _selectedServiceNames;
      final booking = await BookingRepository(widget.api).create(
        widget.session.token,
        services: selected,
        address: address['address']?.toString() ?? '',
        pinCode: address['pinCode']?.toString() ?? '',
        scheduledFor: _scheduled.toIso8601String(),
        durationMinutes: _duration,
        specialInstructions: _specialInstructions.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _confirmedBooking = {
          'id': booking.id,
          'service': booking.service,
          'address': booking.address,
          'pinCode': booking.pinCode,
          'scheduledFor': booking.scheduledFor,
          'durationMinutes': booking.durationMinutes,
          'specialInstructions': booking.specialInstructions,
          'status': booking.status,
          'worker': booking.worker,
        };
        _reviewing = false;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Widget _buildReview() {
    final address = _selectedAddress;
    final notes = _specialInstructions.text.trim();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepTitle(number: '3', title: 'Review booking'),
        const SizedBox(height: 10),
        const Text(
          'Confirm the details before the request is sent to MaidItQuick operations.',
          style: TextStyle(color: BrandColors.muted),
        ),
        const SizedBox(height: 18),
        _ReviewCard(
          title: 'Services',
          icon: Icons.cleaning_services_outlined,
          value: _selectedServiceNames.join('\n'),
          onEdit: _editBooking,
        ),
        _ReviewCard(
          title: 'Address',
          icon: Icons.location_on_outlined,
          value: address == null
              ? ''
              : '${address['label'] ?? 'Address'}\n${address['address']}\n${address['pinCode']}',
          onEdit: _editBooking,
        ),
        _ReviewCard(
          title: 'Schedule',
          icon: Icons.event_available_outlined,
          value: _displayDate(_scheduled),
          onEdit: _editBooking,
        ),
        _ReviewCard(
          title: 'Estimated duration',
          icon: Icons.timer_outlined,
          value: '$_duration minutes',
        ),
        _ReviewCard(
          title: 'Notes',
          icon: Icons.notes_outlined,
          value: notes.isEmpty ? 'No special instructions' : notes,
          onEdit: _editBooking,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _booking ? null : _book,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_booking ? 'Confirming...' : 'Confirm booking'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _booking ? null : _editBooking,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit details'),
        ),
        const SizedBox(height: 12),
        const Text(
          'No payment is collected in this MVP. A booking ID is generated after confirmation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: BrandColors.muted),
        ),
      ],
    );
  }

  Widget _buildSuccess(Map<String, dynamic> booking) {
    final reference = 'MIQ-${booking['id']}';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.check_circle_outline,
            color: BrandColors.lime, size: 56),
        const SizedBox(height: 18),
        const Text('Booking confirmed',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Your request has been sent. MaidItQuick operations will assign a partner automatically.',
          style: const TextStyle(color: BrandColors.muted, height: 1.35),
        ),
        const SizedBox(height: 22),
        _ReviewCard(
          title: 'Booking ID',
          icon: Icons.confirmation_number_outlined,
          value: reference,
        ),
        _ReviewCard(
          title: 'Status',
          icon: Icons.track_changes_outlined,
          value: _bookingStatusLabel(booking['status']?.toString() ?? ''),
        ),
        _ReviewCard(
          title: 'Address',
          icon: Icons.location_on_outlined,
          value: booking['address']?.toString() ?? '',
        ),
        _ReviewCard(
          title: 'Date and time',
          icon: Icons.event_available_outlined,
          value: _displayBookingDate(booking['scheduledFor']?.toString()),
        ),
        _ReviewCard(
          title: 'Duration',
          icon: Icons.timer_outlined,
          value: '${booking['durationMinutes'] ?? _duration} minutes',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.home_outlined),
          label: const Text('Back to dashboard'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _confirmedBooking = null;
              _reviewing = false;
              _specialInstructions.clear();
              _scheduled = _nextAvailableSlot();
            });
          },
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Book another service'),
        ),
      ],
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
      appBar: AppBar(
        title: const Text('MaidItQuick'),
        actions: [
          if (widget.onEditProfile != null)
            IconButton(
                onPressed: widget.onEditProfile,
                icon: const Icon(Icons.person_outline),
                tooltip: 'Edit profile'),
          IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out')
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _confirmedBooking != null
                  ? _buildSuccess(_confirmedBooking!)
                  : _reviewing
                      ? _buildReview()
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text('Hello, ${widget.session.name}',
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text(
                                'Complete these steps to request home help.',
                                style: TextStyle(color: BrandColors.muted)),
                            const SizedBox(height: 24),
                            const _StepTitle(
                                number: '1', title: 'Service address'),
                            const SizedBox(height: 12),
                            if (_addresses.isNotEmpty) ...[
                              RadioGroup<Map<String, dynamic>>(
                                groupValue: _selectedAddress,
                                onChanged: (value) async {
                                  setState(() {
                                    _selectedAddress = value;
                                    _pin.text =
                                        value?['pinCode']?.toString() ?? '';
                                    _availability = null;
                                  });
                                  await _checkAvailability();
                                },
                                child: Column(
                                  children: _addresses
                                      .map((address) => Card(
                                            child: Column(
                                              children: [
                                                RadioListTile<
                                                    Map<String, dynamic>>(
                                                  value: address,
                                                  activeColor: BrandColors.lime,
                                                  title: Row(
                                                    children: [
                                                      Expanded(
                                                          child: Text(address[
                                                                      'label']
                                                                  ?.toString() ??
                                                              'Address')),
                                                      if (address[
                                                              'defaultAddress'] ==
                                                          true)
                                                        const Chip(
                                                            label:
                                                                Text('Default'),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact),
                                                    ],
                                                  ),
                                                  subtitle: Text(
                                                      '${address['address']}\n${address['pinCode']}',
                                                      style: const TextStyle(
                                                          color: BrandColors
                                                              .muted)),
                                                ),
                                                OverflowBar(
                                                  alignment:
                                                      MainAxisAlignment.end,
                                                  spacing: 4,
                                                  children: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            _startEditingAddress(
                                                                address),
                                                        child:
                                                            const Text('Edit')),
                                                    TextButton(
                                                        onPressed: address[
                                                                    'defaultAddress'] ==
                                                                true
                                                            ? null
                                                            : () =>
                                                                _setDefaultAddress(
                                                                    address),
                                                        child: const Text(
                                                            'Set default')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            _deleteAddress(
                                                                address),
                                                        child: const Text(
                                                            'Delete')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                              const Divider(),
                            ],
                            TextField(
                                controller: _label,
                                decoration: const InputDecoration(
                                    labelText: 'Address nickname',
                                    hintText: 'Home, Work, etc.')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _houseNumber,
                                decoration: const InputDecoration(
                                    labelText: 'House number')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _building,
                                decoration: const InputDecoration(
                                    labelText: 'Building (optional)')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _street,
                                decoration:
                                    const InputDecoration(labelText: 'Street')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _area,
                                decoration:
                                    const InputDecoration(labelText: 'Area')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _landmark,
                                decoration: const InputDecoration(
                                    labelText: 'Landmark (optional)')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _city,
                                decoration:
                                    const InputDecoration(labelText: 'City')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _state,
                                decoration:
                                    const InputDecoration(labelText: 'State')),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _pin,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                  labelText: 'PIN code', counterText: ''),
                              onChanged: (_) =>
                                  setState(() => _availability = null),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _savingAddress
                                      ? null
                                      : () => _saveAddress(),
                                  icon: const Icon(
                                      Icons.add_location_alt_outlined),
                                  label: Text(_savingAddress
                                      ? 'Saving...'
                                      : _editingAddressId == null
                                          ? 'Save this address'
                                          : 'Update address'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (_editingAddressId != null)
                                IconButton(
                                    onPressed: _resetAddressForm,
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Cancel edit'),
                              IconButton(
                                  onPressed: _checkAvailability,
                                  icon: const Icon(Icons.bolt_outlined),
                                  tooltip: 'Check availability'),
                            ]),
                            if (_availability != null) ...[
                              const SizedBox(height: 14),
                              _AvailabilityCard(data: _availability!)
                            ],
                            const SizedBox(height: 28),
                            const _StepTitle(
                                number: '2', title: 'Choose service and time'),
                            const SizedBox(height: 12),
                            if (_services.isEmpty)
                              const Text('No services are configured yet.',
                                  style: TextStyle(color: BrandColors.muted))
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _services.map((service) {
                                  final name =
                                      service['name']?.toString() ?? '';
                                  final selected =
                                      _selectedServices.contains(name);
                                  final price =
                                      ((service['pricePaise'] ?? 0) as num) ~/
                                          100;
                                  return FilterChip(
                                    selected: selected,
                                    showCheckmark: true,
                                    avatar: const Icon(
                                        Icons.cleaning_services_outlined,
                                        size: 18),
                                    label: Text('$name · ₹$price'),
                                    onSelected: (_) => _toggleService(name),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 14),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.timer_outlined,
                                    color: BrandColors.lime),
                                title: const Text('Estimated duration'),
                                subtitle: Text(_selectedServices.isEmpty
                                    ? 'Select services to calculate duration'
                                    : '$_duration minutes based on ${_selectedServices.length} selected service${_selectedServices.length == 1 ? '' : 's'}'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _pickSchedule,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(
                                  'Date: ${_scheduled.day}/${_scheduled.month}/${_scheduled.year}'),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _timeSlots.map((slot) {
                                final selected =
                                    TimeOfDay.fromDateTime(_scheduled) == slot;
                                final available = _slotAvailable(slot);
                                return ChoiceChip(
                                  selected: selected,
                                  label: Text(_slotLabel(slot)),
                                  onSelected: available
                                      ? (_) => _selectSlot(slot)
                                      : null,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _specialInstructions,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Special instructions (optional)',
                                hintText:
                                    'Ring bell twice, bring ladder, pet inside, call before arrival',
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _booking ? null : _reviewBooking,
                              icon: const Icon(Icons.fact_check_outlined),
                              label: Text(_booking
                                  ? 'Requesting...'
                                  : 'Review booking'),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                                'No payment is collected in this MVP. The request is created through the live local API.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: BrandColors.muted)),
                          ],
                        ),
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.value,
    this.onEdit,
  });

  final String title;
  final IconData icon;
  final String value;
  final VoidCallback? onEdit;

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
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          color: BrandColors.muted, height: 1.35)),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit $title',
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(
            radius: 14,
            backgroundColor: BrandColors.lime,
            foregroundColor: BrandColors.evergreen,
            child: Text(number,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        ),
      ]);
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString();
    final color = switch (status) {
      'AVAILABLE_NOW' => BrandColors.lime,
      'AVAILABLE_LATER' => Colors.amber,
      _ => Colors.redAccent,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(data['label']?.toString() ?? 'Availability',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(data['message']?.toString() ?? '',
                    style: const TextStyle(color: BrandColors.muted)),
              ])),
        ]),
      ),
    );
  }
}

String _displayDate(DateTime dateTime) {
  final hour =
      dateTime.hour == 0 || dateTime.hour == 12 ? 12 : dateTime.hour % 12;
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
}

String _slotLabel(TimeOfDay slot) {
  final hour = slot.hour == 0 || slot.hour == 12 ? 12 : slot.hour % 12;
  final period = slot.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${slot.minute.toString().padLeft(2, '0')} $period';
}

String _displayBookingDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _displayDate(parsed);
}

String _bookingStatusLabel(String status) {
  return switch (status) {
    'REQUESTED' => 'Confirmed',
    'ASSIGNED' => 'Partner assigned',
    'ON_THE_WAY' => 'On the way',
    'IN_PROGRESS' => 'Started',
    'COMPLETED' => 'Completed',
    _ => status.replaceAll('_', ' '),
  };
}

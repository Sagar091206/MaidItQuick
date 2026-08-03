import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import '../data/customer_addresses_repository.dart';
import '../data/service_catalog_repository.dart';
import 'payment_screen.dart';

/// Four-step booking creation wizard: address → services → schedule → review.
///
/// Step 2 lets the customer pick multiple cleaning tasks and shows the
/// server-calculated duration. Step 3 is the Booking Summary: it shows the
/// server-authoritative itemised quote (subtotal, promo discount, total)
/// before the booking is created.
class BookingWizardScreen extends StatefulWidget {
  const BookingWizardScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
    this.initialServices = const [],
  });

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;

  /// Pre-selected service names (e.g. from the service-details screen).
  final List<String> initialServices;

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  static const _timeSlots = [8, 10, 12, 14, 16, 18];

  final _label = TextEditingController(text: 'Home');
  final _houseNumber = TextEditingController();
  final _building = TextEditingController();
  final _street = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'West Bengal');
  final _pin = TextEditingController();
  final _specialInstructions = TextEditingController();
  final _promo = TextEditingController();

  int _step = 0;
  bool _loading = true;
  String? _loadError;

  List<CatalogService> _services = const [];
  List<CustomerAddress> _addresses = const [];
  CustomerAddress? _selectedAddress;
  AvailabilityStatus? _availability;

  final Set<String> _selected = {};
  int _durationMinutes = 0;

  DateTime _scheduled = DateTime.now().add(const Duration(hours: 2));
  List<Map<String, dynamic>> _slots = const [];

  bool _savingAddress = false;
  bool _creating = false;
  int? _editingAddressId;

  BookingQuote? _quote;
  bool _quoteLoading = false;

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
    _promo.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final catalog = ServiceCatalogRepository(widget.api);
      final addresses = CustomerAddressesRepository(widget.api);
      final data = await Future.wait<dynamic>([
        catalog.listServices(),
        addresses.list(widget.session.token),
      ]);
      final services = List<CatalogService>.from(data[0] as List);
      final saved = List<CustomerAddress>.from(data[1] as List);
      if (!mounted) return;
      setState(() {
        _services = services;
        _addresses = saved;
        _selectedAddress = _defaultAddress(saved);
        for (final name in widget.initialServices) {
          if (services.any((s) => s.name == name)) _selected.add(name);
        }
        if (_selected.isEmpty && services.isNotEmpty) {
          _selected.add(services.first.name);
        }
        _scheduled = _nextSlot();
      });
      await _recomputeDuration();
      await _checkAvailability(showError: false);
      await _loadSlots();
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _loadError = 'Could not load booking details. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CustomerAddress? _defaultAddress(List<CustomerAddress> addresses) {
    if (addresses.isEmpty) return null;
    for (final address in addresses) {
      if (address.defaultAddress) return address;
    }
    return addresses.first;
  }

  List<String> get _selectedNames => _selected.toList()..sort();

  Future<void> _recomputeDuration() async {
    if (_selected.isEmpty) {
      if (mounted) setState(() => _durationMinutes = 0);
      return;
    }
    try {
      final minutes = await ServiceCatalogRepository(widget.api)
          .calculateDuration(_selectedNames, token: widget.session.token);
      if (mounted) setState(() => _durationMinutes = minutes);
    } on ApiException {
      if (mounted) setState(() => _durationMinutes = _selected.length * 60);
    }
  }

  bool get _validPin => RegExp(r'^\d{6}$').hasMatch(_pin.text.trim());

  Future<void> _checkAvailability({bool showError = true}) async {
    if (!_validPin) return;
    try {
      final result = await ServiceCatalogRepository(widget.api)
          .checkAvailability(_pin.text.trim());
      if (mounted) setState(() => _availability = result);
    } on ApiException catch (error) {
      if (showError && mounted) _showMessage(error.message);
    }
  }

  Future<void> _loadSlots() async {
    if (!_validPin) return;
    try {
      final payload = await ServiceCatalogRepository(widget.api)
          .fetchSlots(_pin.text.trim(), _dateKey(_scheduled),
              token: widget.session.token);
      if (mounted) setState(() => _slots = payload);
    } on ApiException {
      // Fall back to local slot list.
      if (mounted) {
        setState(() => _slots = _timeSlots
            .map((hour) => {
                  'time': '$hour:00',
                  'available': true,
                })
            .toList());
      }
    }
  }

  // ── Address helpers ───────────────────────────────────────────────────────

  bool get _addressFormValid =>
      _label.text.trim().isNotEmpty &&
      _houseNumber.text.trim().isNotEmpty &&
      _street.text.trim().isNotEmpty &&
      _area.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _state.text.trim().isNotEmpty &&
      _validPin;

  Future<void> _saveAddress() async {
    if (!_addressFormValid) {
      _showMessage('Fill label, house number, street, area, city, state and PIN.');
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final repo = CustomerAddressesRepository(widget.api);
      final draft = CustomerAddressDraft(
        label: _label.text.trim(),
        houseNumber: _houseNumber.text.trim(),
        building: _building.text.trim(),
        street: _street.text.trim(),
        area: _area.text.trim(),
        landmark: _landmark.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        pinCode: _pin.text.trim(),
        defaultAddress: _addresses.isEmpty || _editingAddressId == null,
      );
      final saved = _editingAddressId == null
          ? await repo.create(widget.session.token, draft)
          : await repo.update(widget.session.token, _editingAddressId!, draft);
      if (!mounted) return;
      setState(() {
        if (_editingAddressId == null) {
          _addresses = [saved, ..._addresses.where((a) => a.id != saved.id)];
        } else {
          _addresses = _addresses
              .map((a) => a.id == saved.id ? saved : a)
              .toList();
        }
        _selectedAddress = saved;
        _editingAddressId = null;
        _availability = null;
      });
      await _checkAvailability(showError: false);
      await _loadSlots();
      _showMessage('Address saved.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  void _startEditingAddress(CustomerAddress address) {
    setState(() {
      _editingAddressId = address.id;
      _label.text = address.label;
      _houseNumber.text = address.houseNumber;
      _building.text = address.building;
      _street.text = address.street;
      _area.text = address.area;
      _landmark.text = address.landmark;
      _city.text = address.city;
      _state.text = address.state;
      _pin.text = address.pinCode;
    });
    _step = 0;
  }

  Future<void> _setDefault(CustomerAddress address) async {
    try {
      final saved = await CustomerAddressesRepository(widget.api)
          .setDefault(widget.session.token, address.id);
      if (!mounted) return;
      setState(() {
        _addresses = _addresses
            .map((a) => a.id == saved.id
                ? saved
                : CustomerAddress(
                    id: a.id,
                    label: a.label,
                    address: a.address,
                    pinCode: a.pinCode,
                    houseNumber: a.houseNumber,
                    building: a.building,
                    street: a.street,
                    area: a.area,
                    landmark: a.landmark,
                    city: a.city,
                    state: a.state,
                    defaultAddress: false,
                    latitude: a.latitude,
                    longitude: a.longitude,
                  ))
            .toList();
        _selectedAddress = saved;
        _pin.text = saved.pinCode;
      });
      await _checkAvailability(showError: false);
      await _loadSlots();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('Delete ${address.label} from your saved addresses?'),
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
          .delete(widget.session.token, address.id);
      if (!mounted) return;
      setState(() {
        _addresses = _addresses.where((a) => a.id != address.id).toList();
        if (_selectedAddress?.id == address.id) {
          _selectedAddress = _defaultAddress(_addresses);
        }
      });
      _showMessage('Address removed.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  // ── Schedule helpers ──────────────────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DateTime _nextSlot() {
    final now = DateTime.now();
    for (final hour in _timeSlots) {
      final candidate = DateTime(now.year, now.month, now.day, hour);
      if (candidate.isAfter(now.add(const Duration(minutes: 30))) &&
          !candidate.difference(now).isNegative) {
        return candidate;
      }
    }
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, _timeSlots.first);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    setState(() =>
        _scheduled = DateTime(date.year, date.month, date.day, _scheduled.hour));
    await _loadSlots();
  }

  void _pickSlot(int hour) {
    final candidate =
        DateTime(_scheduled.year, _scheduled.month, _scheduled.day, hour);
    if (!candidate.isAfter(DateTime.now())) return;
    setState(() => _scheduled = candidate);
  }

  String _slotLabel(int hour) {
    final h = hour == 0 || hour == 12 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:00 $period';
  }

  // ── Quote (Booking Summary pricing) ───────────────────────────────────────

  Future<void> _loadQuote() async {
    if (_selected.isEmpty) return;
    setState(() => _quoteLoading = true);
    try {
      final quote = await ServiceCatalogRepository(widget.api).fetchQuote(
        widget.session.token,
        services: _selectedNames,
        durationMinutes: _durationMinutes,
        promoCode: _promo.text.trim(),
      );
      if (mounted) setState(() => _quote = quote);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load the price estimate. Try again.');
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _applyPromo() => _loadQuote();

  // ── Validation & creation ─────────────────────────────────────────────────

  bool _validateStep(int next) {
    switch (next) {
      case 1:
        if (_selectedAddress == null) {
          _showMessage('Save or choose a service address first.');
          return false;
        }
        if (_availability?.status == 'NOT_AVAILABLE') {
          _showMessage('MaidItQuick is not available at this PIN code yet.');
          return false;
        }
        return true;
      case 2:
        if (_selected.isEmpty) {
          _showMessage('Choose at least one cleaning service.');
          return false;
        }
        return true;
      case 3:
        if (!_scheduled.isAfter(DateTime.now())) {
          _showMessage('Choose an upcoming time slot.');
          return false;
        }
        return true;
    }
    return true;
  }

  void _next() {
    final next = _step + 1;
    if (!_validateStep(next)) return;
    setState(() => _step = next);
    if (next == 3) _loadQuote();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _createBooking() async {
    final address = _selectedAddress;
    if (address == null) return;
    setState(() => _creating = true);
    try {
      final booking = await BookingRepository(widget.api).create(
        widget.session.token,
        services: _selectedNames,
        address: address.address,
        pinCode: address.pinCode,
        scheduledFor: _scheduled.toIso8601String(),
        durationMinutes: _durationMinutes,
        promoCode: _promo.text.trim(),
        specialInstructions: _specialInstructions.text.trim(),
      );
      if (!mounted) return;
      // Hand off to the payment screen. Pop the wizard first so the back
      // stack stays clean: dashboard → payment → confirmation → track.
      Navigator.of(context).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            api: widget.api,
            session: widget.session,
            booking: booking,
          ),
        ),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a service'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: LinearProgressIndicator(
              value: (_step + 1) / 4,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 4)
            : _loadError != null
                ? ErrorStateView(message: _loadError!, onRetry: _loadInitialData)
                : Column(
                    children: [
                      Expanded(
                        child: IndexedStack(
                          index: _step,
                          children: [
                            _buildAddressStep(),
                            _buildServicesStep(),
                            _buildScheduleStep(),
                            _buildSummaryStep(),
                          ],
                        ),
                      ),
                      _buildNavBar(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildNavBar() {
    final isLast = _step == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _creating ? null : _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: isLast
                  ? (_creating ? null : _createBooking)
                  : _next,
              icon: Icon(isLast
                  ? Icons.check_circle_outline
                  : Icons.arrow_forward),
              label: Text(isLast
                  ? (_creating ? 'Creating...' : 'Confirm booking')
                  : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  // Step 0: address ----------------------------------------------------------

  Widget _buildAddressStep() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: '1. Service address'),
        const SizedBox(height: 8),
        const Text(
          'Only serviceable PIN codes can be booked.',
          style: TextStyle(color: BrandColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_addresses.isEmpty)
          const EmptyStateView(
            icon: Icons.location_off_outlined,
            title: 'No saved addresses',
            message: 'Add your first address to continue.',
          )
        else
          RadioGroup<CustomerAddress>(
            groupValue: _selectedAddress,
            onChanged: (value) {
              setState(() {
                _selectedAddress = value;
                _pin.text = value?.pinCode ?? '';
                _availability = null;
              });
              _checkAvailability(showError: false);
              _loadSlots();
            },
            child: Column(
              children: _addresses
                  .map(
                    (address) => Card(
                      child: RadioListTile<CustomerAddress>(
                        value: address,
                        activeColor: scheme.primary,
                        title: Text(address.label),
                        subtitle:
                            Text('${address.address}\nPIN ${address.pinCode}'),
                        secondary: OverflowBar(
                          spacing: 4,
                          children: [
                            TextButton(
                                onPressed: () => _startEditingAddress(address),
                                child: const Text('Edit')),
                            if (!address.defaultAddress)
                              TextButton(
                                  onPressed: () => _setDefault(address),
                                  child: const Text('Default')),
                            TextButton(
                                onPressed: () => _deleteAddress(address),
                                child: const Text('Delete')),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 14),
        SectionHeader(
            title: _editingAddressId == null ? 'Add a new address' : 'Edit address'),
        const SizedBox(height: 10),
        TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Nickname (Home, Work…)')),
        const SizedBox(height: 10),
        TextField(
            controller: _houseNumber,
            decoration: const InputDecoration(labelText: 'House number')),
        const SizedBox(height: 10),
        TextField(
            controller: _building,
            decoration:
                const InputDecoration(labelText: 'Building (optional)')),
        const SizedBox(height: 10),
        TextField(
            controller: _street,
            decoration: const InputDecoration(labelText: 'Street')),
        const SizedBox(height: 10),
        TextField(
            controller: _area,
            decoration: const InputDecoration(labelText: 'Area')),
        const SizedBox(height: 10),
        TextField(
            controller: _landmark,
            decoration: const InputDecoration(labelText: 'Landmark (optional)')),
        const SizedBox(height: 10),
        TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: 10),
        TextField(
            controller: _state,
            decoration: const InputDecoration(labelText: 'State')),
        const SizedBox(height: 10),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN code', counterText: ''),
          onChanged: (_) => setState(() => _availability = null),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _savingAddress ? null : _saveAddress,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(_savingAddress
              ? 'Saving…'
              : _editingAddressId == null
                  ? 'Save this address'
                  : 'Update address'),
        ),
        if (_availability != null && _availability!.available) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.primary.withValues(alpha: 0.14),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: scheme.primary),
              title: Text(_availability!.label),
              subtitle: Text(_availability!.message),
            ),
          ),
        ],
        if (_availability?.status == 'NOT_AVAILABLE') ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.error.withValues(alpha: 0.12),
            child: ListTile(
              leading: Icon(Icons.error_outline, color: scheme.error),
              title: const Text('Not serviceable'),
              subtitle: Text(_availability?.message ?? ''),
            ),
          ),
        ],
      ],
    );
  }

  // Step 1: services ---------------------------------------------------------

  Widget _buildServicesStep() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: '2. Choose cleaning tasks'),
        const SizedBox(height: 8),
        const Text(
          'Select multiple tasks — the duration is calculated automatically.',
          style: TextStyle(color: BrandColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_services.isEmpty)
          const EmptyStateView(
            icon: Icons.cleaning_services_outlined,
            title: 'No services available',
            message: 'The catalog is empty. Try again later.',
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _services.map((service) {
              final selected = _selected.contains(service.name);
              return FilterChip(
                selected: selected,
                showCheckmark: true,
                avatar: Text(
                    service.emoji.isEmpty ? '🧽' : service.emoji,
                    style: const TextStyle(fontSize: 16)),
                label: Text(
                    '${service.name} · ₹${(service.pricePaise / 100).round()}'),
                onSelected: (_) => _toggleService(service),
              );
            }).toList(),
          ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: Icon(Icons.timer_outlined, color: scheme.primary),
            title: const Text('Estimated duration'),
            subtitle: Text(_selected.isEmpty
                ? 'Select tasks to calculate the duration'
                : '$_durationMinutes minutes for ${_selected.length} task${_selected.length == 1 ? '' : 's'}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.cleaning_services_outlined,
                color: scheme.primary),
            title: const Text('You provide the supplies'),
            subtitle: const Text(
                'Buckets, mops, cloths and cleaning agents are arranged by you.'),
          ),
        ),
      ],
    );
  }

  void _toggleService(CatalogService service) {
    setState(() {
      if (_selected.contains(service.name)) {
        if (_selected.length == 1) {
          _showMessage('Choose at least one service.');
          return;
        }
        _selected.remove(service.name);
      } else {
        _selected.add(service.name);
      }
    });
    _recomputeDuration();
  }

  // Step 2: schedule ---------------------------------------------------------

  Widget _buildScheduleStep() {
    final slots = _slots;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: '3. Schedule'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
              'Date: ${_scheduled.day}/${_scheduled.month}/${_scheduled.year}'),
        ),
        const SizedBox(height: 14),
        const Text('Time slots',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (slots.isEmpty)
              for (final hour in _timeSlots)
                _slotChip(hour)
            else
              for (final slot in slots)
                _slotChip(_hourOf(slot['time']?.toString() ?? '')),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _specialInstructions,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Special instructions (optional)',
            hintText: 'Ring bell twice, pet inside, call before arrival',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }

  int _hourOf(String time) {
    final parts = time.split(':');
    if (parts.isEmpty) return 8;
    return int.tryParse(parts.first) ?? 8;
  }

  Widget _slotChip(int hour) {
    final candidate =
        DateTime(_scheduled.year, _scheduled.month, _scheduled.day, hour);
    final past = !candidate.isAfter(DateTime.now());
    final selected = _scheduled.hour == hour;
    return ChoiceChip(
      label: Text(_slotLabel(hour)),
      selected: selected,
      onSelected: past ? null : (_) => _pickSlot(hour),
    );
  }

  // Step 3: summary (Booking Summary) ----------------------------------------

  Widget _buildSummaryStep() {
    final address = _selectedAddress;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: '4. Review booking'),
        const SizedBox(height: 8),
        _ReviewCard(
          title: 'Tasks',
          icon: Icons.cleaning_services_outlined,
          value: _selectedNames.join('\n'),
        ),
        _ReviewCard(
          title: 'Address',
          icon: Icons.location_on_outlined,
          value: address == null
              ? ''
              : '${address.label}\n${address.address}\nPIN ${address.pinCode}',
        ),
        _ReviewCard(
          title: 'Schedule',
          icon: Icons.event_available_outlined,
          value:
              '${_scheduled.day}/${_scheduled.month}/${_scheduled.year}, ${_slotLabel(_scheduled.hour)}',
        ),
        _ReviewCard(
          title: 'Duration',
          icon: Icons.timer_outlined,
          value: '$_durationMinutes minutes',
        ),
        _ReviewCard(
          title: 'Notes',
          icon: Icons.notes_outlined,
          value: _specialInstructions.text.trim().isEmpty
              ? 'None'
              : _specialInstructions.text.trim(),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _quoteLoading
                ? const SkeletonBox(width: double.infinity, height: 120)
                : _quote == null
                    ? Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimated total',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              Text(_estimateTotal(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loadQuote,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Load price estimate'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in _quote!.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(line.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700))),
                                  Text(formatPaise(line.amountPaise)),
                                ],
                              ),
                            ),
                          const Divider(),
                          _PriceRow(
                              label: 'Subtotal', value: _quote!.subtotalPaise),
                          if (_quote!.discountPaise > 0)
                            _PriceRow(
                              label: 'Discount (${_quote!.promoCode})',
                              value: -_quote!.discountPaise,
                            ),
                          if (_quote!.taxPaise > 0)
                            _PriceRow(label: 'GST (18%)', value: _quote!.taxPaise),
                          if (_quote!.convenienceFeePaise > 0)
                            _PriceRow(
                                label: 'Convenience fee',
                                value: _quote!.convenienceFeePaise),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              Text(formatPaise(_quote!.totalPaise),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _promo,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Promo code (optional)',
            hintText: 'WELCOME50',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
          onSubmitted: (_) => _applyPromo(),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _quoteLoading ? null : _applyPromo,
          icon: const Icon(Icons.bolt_outlined),
          label: Text(_quoteLoading ? 'Applying…' : 'Apply promo'),
        ),
      ],
    );
  }

  String _estimateTotal() {
    if (_selected.isEmpty) return formatPaise(0);
    final hours = _durationMinutes <= 0 ? 1 : _durationMinutes / 60.0;
    final total = _services
        .where((s) => _selected.contains(s.name))
        .fold<int>(0, (sum, s) => sum + (s.pricePaise * hours).round());
    return formatPaise(total);
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
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
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final display = value < 0 ? '-${formatPaise(-value)}' : formatPaise(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.brandMuted)),
          Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

# US-05 — Booking Creation Wizard

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-01..US-04.
> Creates **one new file**; modifies **one file** (`customer_bottom_nav.dart`) to route to it. `CustomerJourneyScreen` in `features/onboarding` is **not touched** (out of scope).
> Chain: US-06 replaces the local estimate with the server quote; US-07 replaces the final handoff with the payment screen; US-08 replaces the inline success view with the confirmation screen.

## 1. Objective

Replace the onboarding-folder booking flow with a dedicated, premium 4-step wizard under `features/booking`:

1. **Address** — pick a saved address or add one (with PIN availability check).
2. **Services** — multi-select cleaning tasks + live duration estimate.
3. **Schedule** — date + server-verified time slots + special instructions.
4. **Summary** — review all details (itemised quote lands in US-06) and confirm.

All data comes from the real APIs (`/api/services`, `/api/customer/addresses`, `/api/availability`, `/api/booking/slots`, `/api/booking/calculate-duration`, `POST /api/bookings`).

## 2. Business rules enforced in the UI

- At least one service selected (backend also enforces).
- PIN must be serviceable (`AVAILABLE_NOW`/`AVAILABLE_LATER`).
- Scheduled time must be in the future.
- Address must be saved before booking.
- One active booking per customer is enforced server-side (US-07 adds the 409 guard); the wizard shows the server message if it occurs.

## 3. New file

`mobile/lib/features/booking/presentation/booking_wizard_screen.dart`

## 4. Implementation — Dart

### 4.1 Modify `customer_bottom_nav.dart` (route swap)

Replace the `_openBookingFlow` body:

```dart
  Future<void> _openBookingFlow() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingWizardScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
```

Update imports (add `booking_wizard_screen.dart`, drop `customer_journey_screen.dart`).

### 4.2 New file: `booking_wizard_screen.dart` (full implementation)

```dart
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_addresses_repository.dart';
import '../data/service_catalog_repository.dart';
import '../data/booking_repository.dart';

/// Four-step booking creation wizard: address → services → schedule → review.
/// US-06 replaces the local estimate with the server quote.
/// US-07 replaces the post-create handoff with the payment screen.
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
          .calculateDuration(_selectedNames);
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
          .fetchSlots(_pin.text.trim(), _dateKey(_scheduled));
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
            .map((a) => CustomerAddress(
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
                  defaultAddress: a.id == saved.id,
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
    setState(() => _scheduled = DateTime(
        date.year, date.month, date.day, _scheduled.hour));
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
    if (_validateStep(next)) setState(() => _step = next);
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
        specialInstructions: _specialInstructions.text.trim(),
      );
      if (!mounted) return;
      _showMessage('Booking MIQ-${booking.id} created.');
      // US-07: replace with PaymentScreen(booking) handoff.
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
          ..._addresses.map(
            (address) => Card(
              child: RadioListTile<CustomerAddress>(
                value: address,
                groupValue: _selectedAddress,
                activeColor: BrandColors.lime,
                onChanged: (value) {
                  setState(() {
                    _selectedAddress = value;
                    _pin.text = value?.pinCode ?? '';
                    _availability = null;
                  });
                  _checkAvailability(showError: false);
                  _loadSlots();
                },
                title: Text(address.label),
                subtitle: Text('${address.address}\nPIN ${address.pinCode}'),
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
          ),
        const SizedBox(height: 14),
        const SectionHeader(
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
            color: BrandColors.lime.withValues(alpha: 0.14),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: BrandColors.lime),
              title: Text(_availability!.label),
              subtitle: Text(_availability!.message),
            ),
          ),
        ],
        if (_availability?.status == 'NOT_AVAILABLE') ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.redAccent.withValues(alpha: 0.12),
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
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
                label: Text('${service.name} · ₹${(service.pricePaise / 100).round()}'),
                onSelected: (_) => _toggleService(service),
              );
            }).toList(),
          ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: BrandColors.lime),
            title: const Text('Estimated duration'),
            subtitle: Text(_selected.isEmpty
                ? 'Select tasks to calculate the duration'
                : '$_durationMinutes minutes for ${_selected.length} task${_selected.length == 1 ? '' : 's'}'),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cleaning_services_outlined,
                color: BrandColors.lime),
            title: Text('You provide the supplies'),
            subtitle: Text(
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
        Text('Time slots',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

  // Step 3: summary ----------------------------------------------------------

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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated total',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(_estimateTotal(), // US-06 replaces with server quote.
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Itemised pricing and promo codes arrive with the payment step. You will confirm the final amount before paying.',
                  style: TextStyle(color: BrandColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
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
          ],
        ),
      ),
    );
  }
}
```

### 4.3 Add `fetchSlots` to `ServiceCatalogRepository` (modify `service_catalog_repository.dart`)

```dart
  /// Fetches the availability of the standard time slots for a PIN and date.
  Future<List<Map<String, dynamic>>> fetchSlots(String pinCode, String date) async {
    final payload = await _api.get(
        '/booking/slots?pinCode=$pinCode&date=$date') as List;
    return List<Map<String, dynamic>>.from(payload);
  }
```

## 5. UI states checklist

- Loading → `SkeletonListView`; Error/retry → `ErrorStateView`; Empty (no addresses/services) → `EmptyStateView`; Success → all four steps render live data; inline availability cards for serviceable/not-serviceable PINs.

## 6. Tests

Widget test (new `mobile/test/features/booking/booking_wizard_screen_test.dart`): with a fake `ApiClient` returning canned services/addresses/slots, assert step navigation renders the address list first and the Continue button advances steps.

## 7. Verification

```
cd D:\MaidItQuick\mobile
flutter analyze
flutter test test/features/booking/booking_wizard_screen_test.dart
```

## 8. Acceptance criteria

- [ ] Wizard replaces the onboarding booking flow route (onboarding files untouched).
- [ ] Address step: saved-address picker + add/edit/delete/default + availability card.
- [ ] Services step: multi-select chips + live duration.
- [ ] Schedule step: date picker + server slots + notes.
- [ ] Summary step: review cards + local estimate (to be replaced by US-06).
- [ ] Create booking posts to `POST /api/bookings` with all fields.

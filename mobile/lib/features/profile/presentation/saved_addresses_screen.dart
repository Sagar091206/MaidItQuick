import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/customer_addresses_repository.dart';

/// Profile management screen for the customer's reusable booking addresses.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, required this.api, required this.session});

  final ApiClient api;
  final Session session;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  late final CustomerAddressesRepository _repository;
  List<CustomerAddress> _addresses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = CustomerAddressesRepository(widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final addresses = await _repository.list(widget.session.token);
      if (mounted) setState(() => _addresses = addresses);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load saved addresses.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit([CustomerAddress? address]) async {
    final draft = await showModalBottomSheet<CustomerAddressDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddressEditor(initial: address),
    );
    if (draft == null || !mounted) return;
    try {
      if (address == null) {
        await _repository.create(widget.session.token, draft);
        _message('Address added.');
      } else {
        await _repository.update(widget.session.token, address.id, draft);
        _message('Address updated.');
      }
      await _load();
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _setDefault(CustomerAddress address) async {
    try {
      await _repository.setDefault(widget.session.token, address.id);
      await _load();
      _message('${address.label} is now your default address.');
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _delete(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from your saved addresses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.delete(widget.session.token, address.id);
      await _load();
      _message('Address deleted.');
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved addresses')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : () => _edit(),
      icon: const Icon(Icons.add), label: const Text('Add address'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Try again')),
                ]),
              ))
            : _addresses.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_off_outlined, size: 44),
                      SizedBox(height: 12),
                      Text('No saved addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text('Add an address here to reuse it when booking.', textAlign: TextAlign.center),
                    ]),
                  ))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final address = _addresses[index];
                        return Card(child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          leading: Icon(address.defaultAddress ? Icons.home : Icons.location_on_outlined),
                          title: Row(children: [
                            Expanded(child: Text(address.label, style: const TextStyle(fontWeight: FontWeight.w800))),
                            if (address.defaultAddress) const Chip(label: Text('Default')),
                          ]),
                          subtitle: Text('${address.address}\nPIN ${address.pinCode}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') _edit(address);
                              if (action == 'default') _setDefault(address);
                              if (action == 'delete') _delete(address);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              if (!address.defaultAddress) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ));
                      },
                    ),
                  ),
  );
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.initial});
  final CustomerAddress? initial;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late final Map<String, TextEditingController> _fields = {
    'label': TextEditingController(text: widget.initial?.label ?? ''),
    'house': TextEditingController(text: widget.initial?.houseNumber ?? ''),
    'building': TextEditingController(text: widget.initial?.building ?? ''),
    'street': TextEditingController(text: widget.initial?.street ?? ''),
    'area': TextEditingController(text: widget.initial?.area ?? ''),
    'landmark': TextEditingController(text: widget.initial?.landmark ?? ''),
    'city': TextEditingController(text: widget.initial?.city ?? ''),
    'state': TextEditingController(text: widget.initial?.state ?? ''),
    'pin': TextEditingController(text: widget.initial?.pinCode ?? ''),
  };
  late bool _defaultAddress = widget.initial?.defaultAddress ?? false;

  @override
  void dispose() { for (final field in _fields.values) { field.dispose(); } super.dispose(); }

  void _save() {
    const required = ['label', 'house', 'street', 'area', 'city', 'state', 'pin'];
    if (required.any((key) => _fields[key]!.text.trim().isEmpty) ||
        !RegExp(r'^\d{6}$').hasMatch(_fields['pin']!.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all required fields and enter a 6-digit PIN.')));
      return;
    }
    Navigator.pop(context, CustomerAddressDraft(
      label: _fields['label']!.text.trim(), houseNumber: _fields['house']!.text.trim(),
      building: _fields['building']!.text.trim(), street: _fields['street']!.text.trim(),
      area: _fields['area']!.text.trim(), landmark: _fields['landmark']!.text.trim(),
      city: _fields['city']!.text.trim(), state: _fields['state']!.text.trim(),
      pinCode: _fields['pin']!.text.trim(), defaultAddress: _defaultAddress,
    ));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.initial == null ? 'Add address' : 'Edit address', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _input('label', 'Nickname (Home, Work)'), _input('house', 'House number'),
        _input('building', 'Building (optional)'), _input('street', 'Street'), _input('area', 'Area'),
        _input('landmark', 'Landmark (optional)'), _input('city', 'City'), _input('state', 'State'),
        _input('pin', 'PIN code', number: true),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Make this my default address'), value: _defaultAddress, onChanged: (value) => setState(() => _defaultAddress = value)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save address' : 'Update address'))),
      ])),
    ),
  );

  Widget _input(String key, String label, {bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: _fields[key], keyboardType: number ? TextInputType.number : null,
      maxLength: key == 'pin' ? 6 : null, decoration: InputDecoration(labelText: label, counterText: key == 'pin' ? '' : null)),
  );
}

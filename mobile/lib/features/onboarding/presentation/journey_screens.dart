import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../core/document_picker.dart';
import '../../auth/data/auth_repository.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onChooseRole});

  final ValueChanged<UserRole> onChooseRole;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 900;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, compact ? 16 : 24, 20, 20),
          children: [
            Center(
              child: Image.asset(
                'assets/branding/maiditquick-wordmark.jpeg',
                height: compact ? 56 : 86,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: compact ? 20 : 40),
            Text(
              'Home help\nin minutes.',
              style: TextStyle(fontSize: compact ? 34 : 42, height: 1.04, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              'Choose how you want to use MaidItQuick. Your account journey is kept separate and secure.',
              style: TextStyle(fontSize: compact ? 14 : 17, color: BrandColors.muted, height: 1.4),
            ),
            SizedBox(height: compact ? 18 : 32),
            _RoleCard(
              icon: Icons.home_outlined,
              title: 'I need home help',
              subtitle: 'Create a customer account, add your address and book a service.',
              action: 'Continue as customer',
              compact: compact,
              onTap: () => onChooseRole(UserRole.customer),
            ),
            SizedBox(height: compact ? 12 : 16),
            _RoleCard(
              icon: Icons.handshake_outlined,
              title: 'I am a maid partner',
              subtitle: 'Create a partner account, submit your KYC and track approval.',
              action: 'Continue as partner',
              outlined: true,
              compact: compact,
              onTap: () => onChooseRole(UserRole.partner),
            ),
            SizedBox(height: compact ? 18 : 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TrustItem(icon: Icons.verified_user_outlined, label: 'Verified\nprofessionals', compact: compact),
                _TrustItem(icon: Icons.flash_on_outlined, label: 'Quick\nbooking', compact: compact),
                _TrustItem(icon: Icons.support_agent_outlined, label: '24/7\nsupport', compact: compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.role, required this.onAuthenticated});

  final ApiClient api;
  final UserRole role;
  final ValueChanged<Session> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegistering = true;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repository = AuthRepository(widget.api);
      if (_isRegistering) {
        await repository.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: widget.role,
        );
      }
      final session = await repository.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to reach MaidItQuick. Check that the local API is running.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Create your ${widget.role.label} account' : 'Welcome back';
    return Scaffold(
      appBar: AppBar(title: Text(widget.role.label)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(widget.role == UserRole.customer ? Icons.home_outlined : Icons.handshake_outlined, size: 46, color: BrandColors.lime),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                widget.role == UserRole.customer
                    ? 'Book trusted help in your locality.'
                    : 'Complete your onboarding and start receiving jobs after approval.',
                style: const TextStyle(color: BrandColors.muted),
              ),
              const SizedBox(height: 28),
              if (_isRegistering) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.evergreen))
                    : Text(_isRegistering ? 'Create account and continue' : 'Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : () => setState(() => _isRegistering = !_isRegistering),
                child: Text(_isRegistering ? 'Already have an account? Sign in' : 'New to MaidItQuick? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerJourneyScreen extends StatefulWidget {
  const CustomerJourneyScreen({super.key, required this.api, required this.session, required this.onLogout});

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<CustomerJourneyScreen> createState() => _CustomerJourneyScreenState();
}

class _CustomerJourneyScreenState extends State<CustomerJourneyScreen> {
  final _label = TextEditingController(text: 'Home');
  final _address = TextEditingController();
  final _pin = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _availability;
  String? _service;
  int _duration = 60;
  DateTime _scheduled = DateTime.now().add(const Duration(hours: 1));
  bool _loading = true;
  bool _savingAddress = false;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final data = await Future.wait<dynamic>([
        widget.api.get('/services'),
        widget.api.get('/customer/addresses', token: widget.session.token),
      ]);
      if (!mounted) return;
      final services = List<Map<String, dynamic>>.from(data[0] as List);
      final addresses = List<Map<String, dynamic>>.from(data[1] as List);
      setState(() {
        _services = services;
        _addresses = addresses;
        _selectedAddress = addresses.isEmpty ? null : addresses.first;
        _service = services.isEmpty ? null : services.first['name']?.toString();
        if (_selectedAddress != null) {
          _pin.text = _selectedAddress!['pinCode']?.toString() ?? '';
        }
      });
      if (_pin.text.length == 6) await _checkAvailability();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load services. Confirm that the API server is running.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (_label.text.trim().isEmpty || _address.text.trim().isEmpty || !_validPin) {
      _showMessage('Enter a label, full address and a six-digit PIN code.');
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final saved = Map<String, dynamic>.from(await widget.api.post(
        '/customer/addresses',
        {'label': _label.text.trim(), 'address': _address.text.trim(), 'pinCode': _pin.text.trim()},
        token: widget.session.token,
      ) as Map);
      if (!mounted) return;
      setState(() {
        _addresses = [saved, ..._addresses];
        _selectedAddress = saved;
        _availability = null;
      });
      await _checkAvailability();
      _showMessage('Address saved. Now choose a service and schedule.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  bool get _validPin => RegExp(r'^\d{6}$').hasMatch(_pin.text.trim());

  Future<void> _checkAvailability() async {
    if (!_validPin) {
      _showMessage('Enter a six-digit PIN code.');
      return;
    }
    try {
      final result = Map<String, dynamic>.from(
        await widget.api.get('/availability?pinCode=${_pin.text.trim()}') as Map,
      );
      if (mounted) setState(() => _availability = result);
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
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduled));
    if (time == null || !mounted) return;
    setState(() => _scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _book() async {
    final address = _selectedAddress;
    if (address == null) {
      _showMessage('Save or choose a service address first.');
      return;
    }
    if (_service == null) {
      _showMessage('No services are configured yet.');
      return;
    }
    if (_availability?['status'] == 'NOT_AVAILABLE') {
      _showMessage('MaidItQuick is not available at this PIN code yet.');
      return;
    }
    setState(() => _booking = true);
    try {
      final booking = Map<String, dynamic>.from(await widget.api.post(
        '/bookings',
        {
          'service': _service,
          'address': address['address']?.toString(),
          'pinCode': address['pinCode']?.toString(),
          'scheduledFor': _scheduled.toIso8601String(),
          'durationMinutes': _duration,
          'optionLabel': 'Standard service',
          'promoCode': '',
        },
        token: widget.session.token,
      ) as Map);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking requested'),
          content: Text('Your ${booking['service']} booking has been created. Reference: MIQ-${booking['id']}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaidItQuick'),
        actions: [IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout), tooltip: 'Sign out')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Hello, ${widget.session.name}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Complete these steps to request home help.', style: TextStyle(color: BrandColors.muted)),
                  const SizedBox(height: 24),
                  const _StepTitle(number: '1', title: 'Service address'),
                  const SizedBox(height: 12),
                  if (_addresses.isNotEmpty) ...[
                    RadioGroup<Map<String, dynamic>>(
                      groupValue: _selectedAddress,
                      onChanged: (value) async {
                        setState(() {
                          _selectedAddress = value;
                          _pin.text = value?['pinCode']?.toString() ?? '';
                          _availability = null;
                        });
                        await _checkAvailability();
                      },
                      child: Column(
                        children: _addresses
                            .map((address) => RadioListTile<Map<String, dynamic>>(
                                  value: address,
                                  activeColor: BrandColors.lime,
                                  title: Text(address['label']?.toString() ?? 'Address'),
                                  subtitle: Text('${address['address']}\n${address['pinCode']}', style: const TextStyle(color: BrandColors.muted)),
                                ))
                            .toList(),
                      ),
                    ),
                    const Divider(),
                  ],
                  TextField(controller: _label, decoration: const InputDecoration(labelText: 'Address label', hintText: 'Home, Work, etc.')),
                  const SizedBox(height: 10),
                  TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Full address')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'PIN code', counterText: ''),
                    onChanged: (_) => setState(() => _availability = null),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingAddress ? null : _saveAddress,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(_savingAddress ? 'Saving...' : 'Save this address'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(onPressed: _checkAvailability, icon: const Icon(Icons.bolt_outlined), tooltip: 'Check availability'),
                  ]),
                  if (_availability != null) ...[const SizedBox(height: 14), _AvailabilityCard(data: _availability!)],
                  const SizedBox(height: 28),
                  const _StepTitle(number: '2', title: 'Choose service and time'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _service,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: _services
                        .map((service) => DropdownMenuItem(value: service['name']?.toString(), child: Text('${service['name']} — ₹${((service['pricePaise'] ?? 0) as num) ~/ 100}')))
                        .toList(),
                    onChanged: (value) => setState(() => _service = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _duration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [30, 60, 90, 120].map((minutes) => DropdownMenuItem(value: minutes, child: Text('$minutes minutes'))).toList(),
                    onChanged: (value) => setState(() => _duration = value ?? 60),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickSchedule,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('Schedule: ${_displayDate(_scheduled)}'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _booking ? null : _book,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_booking ? 'Requesting...' : 'Request this service'),
                  ),
                  const SizedBox(height: 10),
                  const Text('No payment is collected in this MVP. The request is created through the live local API.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: BrandColors.muted)),
                ],
              ),
            ),
    );
  }
}

class PartnerJourneyScreen extends StatefulWidget {
  const PartnerJourneyScreen({super.key, required this.api, required this.session, required this.onLogout});

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<PartnerJourneyScreen> createState() => _PartnerJourneyScreenState();
}

class _PartnerJourneyScreenState extends State<PartnerJourneyScreen> {
  final _last4 = TextEditingController();
  final _ifsc = TextEditingController();
  Map<String, dynamic>? _profile;
  KycDocument? _document;
  bool _loading = true;
  bool _uploading = false;
  bool _savingPayout = false;
  bool _settingAvailability = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _last4.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = Map<String, dynamic>.from(await widget.api.get('/workers/me', token: widget.session.token) as Map);
      if (mounted) setState(() => _profile = data);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument() async {
    try {
      final document = await KycDocumentPicker.pick();
      if (document == null || !mounted) return;
      setState(() => _document = document);
    } on KycDocumentPickerException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _submitKyc() async {
    final document = _document;
    if (document == null) {
      _showMessage('Choose a PDF, JPG or PNG identity document first.');
      return;
    }
    if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('The document must be smaller than 5 MB.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final profile = Map<String, dynamic>.from(await widget.api.multipartPost(
        '/workers/me/kyc',
        token: widget.session.token,
        bytes: document.bytes,
        fileName: document.name,
        mimeType: document.mimeType,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('KYC submitted. An admin must approve it before you can go available.');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _savePayout() async {
    if (!RegExp(r'^\d{4}$').hasMatch(_last4.text) || _ifsc.text.trim().isEmpty) {
      _showMessage('Enter the final four account digits and IFSC code.');
      return;
    }
    setState(() => _savingPayout = true);
    try {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/payout-details',
        {'accountLast4': _last4.text, 'ifsc': _ifsc.text.trim().toUpperCase()},
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Payout details saved for verification.');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _savingPayout = false);
    }
  }

  Future<void> _setAvailable() async {
    setState(() => _settingAvailability = true);
    try {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/availability',
        {'status': 'AVAILABLE'},
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('You are now available for jobs.');
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _settingAvailability = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner onboarding'),
        actions: [IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout), tooltip: 'Sign out')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Welcome, ${widget.session.name}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Finish each required item. Jobs become available after KYC approval.', style: TextStyle(color: BrandColors.muted)),
                  const SizedBox(height: 24),
                  _PartnerStatusCard(title: 'Identity verification', status: profile?['kycStatus']?.toString() ?? 'NOT_SUBMITTED', icon: Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _PartnerStatusCard(title: 'Background check', status: profile?['backgroundCheckStatus']?.toString() ?? 'NOT_SUBMITTED', icon: Icons.shield_outlined),
                  const SizedBox(height: 12),
                  _PartnerStatusCard(title: 'Job availability', status: profile?['availability']?.toString() ?? 'OFFLINE', icon: Icons.work_outline),
                  const SizedBox(height: 28),
                  const _StepTitle(number: '1', title: 'Upload identity document'),
                  const SizedBox(height: 8),
                  const Text('Accepted: PDF, JPG or PNG. Maximum file size: 5 MB.', style: TextStyle(color: BrandColors.muted)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _pickDocument, icon: const Icon(Icons.upload_file_outlined), label: Text(_document?.name ?? 'Choose document')),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _uploading ? null : _submitKyc, child: Text(_uploading ? 'Submitting...' : 'Submit KYC for review')),
                  const SizedBox(height: 28),
                  const _StepTitle(number: '2', title: 'Add payout details'),
                  const SizedBox(height: 12),
                  TextField(controller: _last4, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Final four account digits', counterText: '')),
                  const SizedBox(height: 12),
                  TextField(controller: _ifsc, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'IFSC code')),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _savingPayout ? null : _savePayout, child: Text(_savingPayout ? 'Saving...' : 'Save payout details')),
                  const SizedBox(height: 28),
                  const _StepTitle(number: '3', title: 'Start receiving jobs'),
                  const SizedBox(height: 8),
                  const Text('This only succeeds after the admin has approved your KYC.', style: TextStyle(color: BrandColors.muted)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _settingAvailability ? null : _setAvailable,
                    icon: const Icon(Icons.toggle_on_outlined),
                    label: Text(_settingAvailability ? 'Updating...' : 'Go available'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap, this.outlined = false, this.compact = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: BrandColors.lime, size: compact ? 24 : 30),
          SizedBox(height: compact ? 8 : 14),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 18 : 20)),
          SizedBox(height: compact ? 4 : 6),
          Text(subtitle, style: TextStyle(color: BrandColors.muted, height: 1.3, fontSize: compact ? 13 : 14)),
          SizedBox(height: compact ? 10 : 16),
          if (outlined)
            OutlinedButton(onPressed: onTap, child: Text(action))
          else
            FilledButton(onPressed: onTap, child: Text(action)),
        ]),
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
        CircleAvatar(radius: 14, backgroundColor: BrandColors.lime, foregroundColor: BrandColors.evergreen, child: Text(number, style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['label']?.toString() ?? 'Availability', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(data['message']?.toString() ?? '', style: const TextStyle(color: BrandColors.muted)),
          ])),
        ]),
      ),
    );
  }
}

class _PartnerStatusCard extends StatelessWidget {
  const _PartnerStatusCard({required this.title, required this.status, required this.icon});
  final String title;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED' || status == 'AVAILABLE';
    final pending = status == 'PENDING';
    final color = approved ? BrandColors.lime : pending ? Colors.amber : BrandColors.muted;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label, this.compact = false});
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: BrandColors.lime, size: compact ? 20 : 24),
        SizedBox(height: compact ? 4 : 8),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: BrandColors.muted, fontSize: compact ? 11 : 14)),
      ]);
}

String _displayDate(DateTime dateTime) {
  final hour = dateTime.hour == 0 || dateTime.hour == 12 ? 12 : dateTime.hour % 12;
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
}

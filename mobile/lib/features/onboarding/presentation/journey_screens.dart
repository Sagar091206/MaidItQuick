import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              style: TextStyle(
                  fontSize: compact ? 34 : 42,
                  height: 1.04,
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              'Choose how you want to use MaidItQuick. Your account journey is kept separate and secure.',
              style: TextStyle(
                  fontSize: compact ? 14 : 17,
                  color: BrandColors.muted,
                  height: 1.4),
            ),
            SizedBox(height: compact ? 18 : 32),
            _RoleCard(
              icon: Icons.home_outlined,
              title: 'I need home help',
              subtitle:
                  'Create a customer account, add your address and book a service.',
              action: 'Continue as customer',
              compact: compact,
              onTap: () => onChooseRole(UserRole.customer),
            ),
            SizedBox(height: compact ? 12 : 16),
            _RoleCard(
              icon: Icons.handshake_outlined,
              title: 'I am a partner',
              subtitle:
                  'Create a partner account, submit your KYC and track approval.',
              action: 'Continue as partner',
              outlined: true,
              compact: compact,
              onTap: () => onChooseRole(UserRole.partner),
            ),
            SizedBox(height: compact ? 18 : 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TrustItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Verified\nprofessionals',
                    compact: compact),
                _TrustItem(
                    icon: Icons.flash_on_outlined,
                    label: 'Quick\nbooking',
                    compact: compact),
                _TrustItem(
                    icon: Icons.support_agent_outlined,
                    label: '24/7\nsupport',
                    compact: compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen(
      {super.key,
      required this.api,
      required this.role,
      required this.onBack,
      required this.onAuthenticated});

  final ApiClient api;
  final UserRole role;
  final VoidCallback onBack;
  final ValueChanged<Session> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  OtpChallenge? _partnerChallenge;
  bool _isRegistering = true;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.role == UserRole.partner) {
      await _submitPartner();
      return;
    }
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
      final session = await repository.login(
          email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
          'Unable to reach MaidItQuick. Check that the local API is running.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitPartner() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repository = AuthRepository(widget.api);
      final challenge = _partnerChallenge;
      if (challenge == null) {
        final next = _isRegistering
            ? await repository.startPartnerSignup(
                name: _name.text.trim(), phone: _phone.text.trim())
            : await repository.startPartnerLogin(phone: _phone.text.trim());
        if (!mounted) return;
        setState(() {
          _partnerChallenge = next;
          _otp.clear();
        });
        _showMessage('OTP sent to ${next.phone}.');
      } else {
        final session = await repository.verifyPartnerOtp(
          phone: challenge.phone,
          purpose: _isRegistering ? 'signup' : 'login',
          otp: _otp.text.trim(),
        );
        if (!mounted) return;
        widget.onAuthenticated(session);
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
          'Unable to reach MaidItQuick. Check that the local API is running.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _changePartnerPhone() {
    setState(() {
      _partnerChallenge = null;
      _otp.clear();
    });
  }

  Future<void> _resendPartnerOtp() async {
    final challenge = _partnerChallenge;
    if (challenge == null) return;
    setState(() => _submitting = true);
    try {
      final repository = AuthRepository(widget.api);
      final next = _isRegistering
          ? await repository.startPartnerSignup(
              name: _name.text.trim(), phone: challenge.phone)
          : await repository.startPartnerLogin(phone: challenge.phone);
      if (!mounted) return;
      setState(() {
        _partnerChallenge = next;
        _otp.clear();
      });
      _showMessage('OTP resent to ${next.phone}.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
          'Unable to reach MaidItQuick. Check that the local API is running.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _partnerChallenge = null;
      _otp.clear();
    });
  }

  void _handleAuthBack() {
    if (_submitting) return;
    if (_partnerChallenge != null) {
      _changePartnerPhone();
      return;
    }
    widget.onBack();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == UserRole.partner) return _buildPartnerAuth();

    final title = _isRegistering
        ? 'Create your ${widget.role.label} account'
        : 'Welcome back';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: _submitting ? null : widget.onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back'),
        title: Text(widget.role.label),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                  widget.role == UserRole.customer
                      ? Icons.home_outlined
                      : Icons.handshake_outlined,
                  size: 46,
                  color: BrandColors.lime),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
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
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline)),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: BrandColors.evergreen))
                    : Text(_isRegistering
                        ? 'Create account and continue'
                        : 'Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : _toggleMode,
                child: Text(_isRegistering
                    ? 'Already have an account? Sign in'
                    : 'New to MaidItQuick? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerAuth() {
    final challenge = _partnerChallenge;
    final title = challenge == null
        ? _isRegistering
            ? 'Create your Partner account'
            : 'Sign in as Partner'
        : 'Enter OTP';
    final subtitle = challenge == null
        ? _isRegistering
            ? 'Start with your name and phone number. We will verify it with an OTP.'
            : 'Enter your phone number and we will send you an OTP.'
        : 'OTP sent to ${_maskPhone(challenge.phone)}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: _submitting ? null : _handleAuthBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back'),
        title: const Text('Partner'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.handshake_outlined,
                  size: 46, color: BrandColors.lime),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: BrandColors.muted)),
              const SizedBox(height: 28),
              if (challenge == null) ...[
                if (_isRegistering) ...[
                  TextFormField(
                    controller: _name,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: const [_PhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    helperText: 'Use country code. India defaults to +91.',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 8
                      ? 'Enter a valid phone number'
                      : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: const [
                    _AsciiDigitInputFormatter(maxLength: 6)
                  ],
                  decoration: InputDecoration(
                    labelText: 'OTP',
                    prefixIcon: const Icon(Icons.password_outlined),
                    counterText: '',
                    helperText: challenge.devOtp == null
                        ? 'Code expires in 10 minutes.'
                        : 'Dev OTP: ${challenge.devOtp}',
                  ),
                  validator: (value) => value == null ||
                          !RegExp(r'^\d{6}$').hasMatch(value.trim())
                      ? 'Enter the six-digit OTP'
                      : null,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                    onPressed: _submitting ? null : _changePartnerPhone,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Change phone number')),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: BrandColors.evergreen))
                    : Text(challenge == null
                        ? _isRegistering
                            ? 'Continue'
                            : 'Send OTP'
                        : 'Verify and continue'),
              ),
              if (challenge == null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : _toggleMode,
                  child: Text(_isRegistering
                      ? 'Already have an account? Sign in'
                      : 'New to MaidItQuick? Create an account'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextButton(
                    onPressed: _submitting ? null : _resendPartnerOtp,
                    child: const Text('Resend OTP')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, phone.length - 6)}******${phone.substring(phone.length - 3)}';
  }
}

class CustomerJourneyScreen extends StatefulWidget {
  const CustomerJourneyScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.onLogout});

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
      _showMessage(
          'Could not load services. Confirm that the API server is running.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (_label.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        !_validPin) {
      _showMessage('Enter a label, full address and a six-digit PIN code.');
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final saved = Map<String, dynamic>.from(await widget.api.post(
        '/customer/addresses',
        {
          'label': _label.text.trim(),
          'address': _address.text.trim(),
          'pinCode': _pin.text.trim()
        },
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
        await widget.api.get('/availability?pinCode=${_pin.text.trim()}')
            as Map,
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
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_scheduled));
    if (time == null || !mounted) return;
    setState(() => _scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
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
          content: Text(
              'Your ${booking['service']} booking has been created. Reference: MIQ-${booking['id']}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
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
          IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out')
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Hello, ${widget.session.name}',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Complete these steps to request home help.',
                      style: TextStyle(color: BrandColors.muted)),
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
                            .map((address) =>
                                RadioListTile<Map<String, dynamic>>(
                                  value: address,
                                  activeColor: BrandColors.lime,
                                  title: Text(address['label']?.toString() ??
                                      'Address'),
                                  subtitle: Text(
                                      '${address['address']}\n${address['pinCode']}',
                                      style: const TextStyle(
                                          color: BrandColors.muted)),
                                ))
                            .toList(),
                      ),
                    ),
                    const Divider(),
                  ],
                  TextField(
                      controller: _label,
                      decoration: const InputDecoration(
                          labelText: 'Address label',
                          hintText: 'Home, Work, etc.')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _address,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Full address')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: 'PIN code', counterText: ''),
                    onChanged: (_) => setState(() => _availability = null),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingAddress ? null : _saveAddress,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(
                            _savingAddress ? 'Saving...' : 'Save this address'),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                  DropdownButtonFormField<String>(
                    initialValue: _service,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: _services
                        .map((service) => DropdownMenuItem(
                            value: service['name']?.toString(),
                            child: Text(
                                '${service['name']} — ₹${((service['pricePaise'] ?? 0) as num) ~/ 100}')))
                        .toList(),
                    onChanged: (value) => setState(() => _service = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _duration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [30, 60, 90, 120]
                        .map((minutes) => DropdownMenuItem(
                            value: minutes, child: Text('$minutes minutes')))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _duration = value ?? 60),
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
                    label: Text(
                        _booking ? 'Requesting...' : 'Request this service'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                      'No payment is collected in this MVP. The request is created through the live local API.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: BrandColors.muted)),
                ],
              ),
            ),
    );
  }
}

class PartnerJourneyScreen extends StatefulWidget {
  const PartnerJourneyScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.onLogout});

  final ApiClient api;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<PartnerJourneyScreen> createState() => _PartnerJourneyScreenState();
}

class _PartnerJourneyScreenState extends State<PartnerJourneyScreen> {
  final _panNumber = TextEditingController();
  final _panName = TextEditingController();
  final _currentAddress = TextEditingController();
  final _permanentAddress = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pinCode = TextEditingController();
  final _services = TextEditingController();
  final _workLocations = TextEditingController();
  final _experience = TextEditingController();
  final _availableWhen = TextEditingController();
  final _accountHolderName = TextEditingController();
  final _last4 = TextEditingController();
  final _ifsc = TextEditingController();
  final _upiId = TextEditingController();
  Map<String, dynamic>? _profile;
  KycDocument? _identityDocument;
  KycDocument? _panDocument;
  KycDocument? _profilePhoto;
  KycDocument? _addressDocument;
  KycDocument? _policeDocument;
  String _payoutMethod = 'BANK';
  bool _partnerCodeAccepted = false;
  bool _loading = true;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _panNumber.dispose();
    _panName.dispose();
    _currentAddress.dispose();
    _permanentAddress.dispose();
    _city.dispose();
    _state.dispose();
    _pinCode.dispose();
    _services.dispose();
    _workLocations.dispose();
    _experience.dispose();
    _availableWhen.dispose();
    _accountHolderName.dispose();
    _last4.dispose();
    _ifsc.dispose();
    _upiId.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = Map<String, dynamic>.from(await widget.api
          .get('/workers/me', token: widget.session.token) as Map);
      if (mounted) setState(() => _profile = data);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument(ValueChanged<KycDocument> onPicked) async {
    try {
      final document = await KycDocumentPicker.pick();
      if (document == null || !mounted) return;
      setState(() => onPicked(document));
    } on KycDocumentPickerException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _acceptConsent() async {
    await _run('consent', () async {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/consent',
        {'accepted': true},
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Consent saved.');
      }
    });
  }

  Future<void> _submitIdentity() async {
    final document = _identityDocument;
    if (document == null) {
      _showMessage('Choose a PDF, JPG or PNG identity document first.');
      return;
    }
    await _uploadDocument(
      action: 'identity',
      endpoint: '/workers/me/identity-document',
      document: document,
      success: 'Identity document submitted for review.',
    );
  }

  Future<void> _submitPan() async {
    final document = _panDocument;
    final pan = _panNumber.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(pan) ||
        _panName.text.trim().isEmpty) {
      _showMessage('Enter a valid PAN number and PAN name.');
      return;
    }
    if (document == null) {
      _showMessage('Choose a PAN document first.');
      return;
    }
    await _uploadDocument(
      action: 'pan',
      endpoint: '/workers/me/pan',
      document: document,
      fields: {'panNumber': pan, 'panName': _panName.text.trim()},
      success: 'PAN submitted for review.',
    );
  }

  Future<void> _submitProfilePhoto() async {
    final document = _profilePhoto;
    if (document == null) {
      _showMessage('Choose a JPG or PNG profile photo first.');
      return;
    }
    await _uploadDocument(
      action: 'photo',
      endpoint: '/workers/me/profile-photo',
      document: document,
      success: 'Profile photo submitted for review.',
    );
  }

  Future<void> _saveAddress() async {
    final document = _addressDocument;
    if (_currentAddress.text.trim().isEmpty ||
        _permanentAddress.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty ||
        !RegExp(r'^\d{6}$').hasMatch(_pinCode.text.trim())) {
      _showMessage(
          'Enter current address, permanent address, city, state and 6 digit PIN.');
      return;
    }
    if (document == null) {
      _showMessage('Choose a PDF, JPG or PNG address proof first.');
      return;
    }
    if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('The document must be smaller than 5 MB.');
      return;
    }
    await _run('address', () async {
      await widget.api.post(
        '/workers/me/address',
        {
          'currentAddress': _currentAddress.text.trim(),
          'permanentAddress': _permanentAddress.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'pinCode': _pinCode.text.trim(),
        },
        token: widget.session.token,
      );
      final profile = Map<String, dynamic>.from(await widget.api.multipartPost(
        '/workers/me/address-proof',
        token: widget.session.token,
        bytes: document.bytes,
        fileName: document.name,
        mimeType: document.mimeType,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Address details and proof submitted for review.');
      }
    });
  }

  Future<void> _submitPoliceVerification() async {
    final document = _policeDocument;
    if (document == null) {
      _showMessage(
          'Choose a police verification certificate or acknowledgement first.');
      return;
    }
    await _uploadDocument(
      action: 'police',
      endpoint: '/workers/me/police-verification',
      document: document,
      success: 'Police verification submitted for review.',
    );
  }

  Future<void> _saveServiceReadiness() async {
    if (_services.text.trim().isEmpty ||
        _workLocations.text.trim().isEmpty ||
        _experience.text.trim().isEmpty ||
        _availableWhen.text.trim().isEmpty ||
        !_partnerCodeAccepted) {
      _showMessage('Complete service details and accept the Partner code.');
      return;
    }
    await _run('readiness', () async {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/service-readiness',
        {
          'serviceCategories': _services.text.trim(),
          'workLocations': _workLocations.text.trim(),
          'experienceSummary': _experience.text.trim(),
          'availabilitySummary': _availableWhen.text.trim(),
          'partnerCodeAccepted': _partnerCodeAccepted,
        },
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Service readiness saved.');
      }
    });
  }

  Future<void> _savePayout() async {
    if (_accountHolderName.text.trim().isEmpty) {
      _showMessage('Enter the payout account holder name.');
      return;
    }
    if (_payoutMethod == 'BANK' &&
        (!RegExp(r'^\d{4}$').hasMatch(_last4.text) ||
            _ifsc.text.trim().isEmpty)) {
      _showMessage('Enter the final four account digits and IFSC code.');
      return;
    }
    if (_payoutMethod == 'UPI' && _upiId.text.trim().isEmpty) {
      _showMessage('Enter the UPI ID.');
      return;
    }
    await _run('payout', () async {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/payout-details',
        {
          'method': _payoutMethod,
          'accountHolderName': _accountHolderName.text.trim(),
          'accountLast4': _last4.text.trim(),
          'ifsc': _ifsc.text.trim().toUpperCase(),
          'upiId': _upiId.text.trim(),
        },
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('Payout details saved for verification.');
      }
    });
  }

  Future<void> _setAvailable() async {
    await _run('available', () async {
      final profile = Map<String, dynamic>.from(await widget.api.post(
        '/workers/me/availability',
        {'status': 'AVAILABLE'},
        token: widget.session.token,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage('You are now available for jobs.');
      }
    });
  }

  Future<void> _uploadDocument({
    required String action,
    required String endpoint,
    required KycDocument document,
    required String success,
    Map<String, String> fields = const {},
  }) async {
    if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('The document must be smaller than 5 MB.');
      return;
    }
    await _run(action, () async {
      final profile = Map<String, dynamic>.from(await widget.api.multipartPost(
        endpoint,
        token: widget.session.token,
        bytes: document.bytes,
        fileName: document.name,
        mimeType: document.mimeType,
        fields: fields,
      ) as Map);
      if (mounted) {
        setState(() => _profile = profile);
        _showMessage(success);
      }
    });
  }

  Future<void> _run(String action, Future<void> Function() work) async {
    setState(() => _busyAction = action);
    try {
      await work();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final readyForJobs = profile?['readyForJobs'] == true;
    final consentAccepted = profile?['consentAccepted'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner onboarding'),
        actions: [
          IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out')
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !consentAccepted
              ? _PartnerConsentScreen(
                  partnerName: widget.session.name,
                  saving: _isBusy('consent'),
                  onAccept: _acceptConsent,
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Welcome, ${widget.session.name}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text(
                          'Finish each required item. Jobs become available after compliance and safety approval.',
                          style: TextStyle(color: BrandColors.muted)),
                      const SizedBox(height: 24),
                      _PartnerStatusCard(
                          title: 'Identity verification',
                          status: _status('identityStatus'),
                          icon: Icons.badge_outlined),
                      const SizedBox(height: 12),
                      _PartnerStatusCard(
                          title: 'PAN verification',
                          status: _status('panStatus'),
                          icon: Icons.assignment_ind_outlined),
                      const SizedBox(height: 12),
                      _PartnerStatusCard(
                          title: 'Selfie / profile photo',
                          status: _status('selfieStatus'),
                          icon: Icons.account_circle_outlined),
                      const SizedBox(height: 12),
                      _PartnerStatusCard(
                          title: 'Address verification',
                          status: _status('addressStatus'),
                          icon: Icons.location_on_outlined),
                      const SizedBox(height: 12),
                      _PartnerStatusCard(
                          title: 'Police verification',
                          status: _status('backgroundCheckStatus'),
                          icon: Icons.shield_outlined),
                      const SizedBox(height: 28),
                      _PartnerFormCard(
                        number: '1',
                        title: 'Upload identity document',
                        children: [
                          const Text(
                              'Accepted: PAN, driving licence, voter ID, passport or masked Aadhaar as PDF, JPG or PNG.',
                              style: TextStyle(color: BrandColors.muted)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: () => _pickDocument(
                                  (doc) => _identityDocument = doc),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(_identityDocument?.name ??
                                  'Choose identity document')),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed:
                                  _isBusy('identity') ? null : _submitIdentity,
                              child: Text(
                                  _buttonLabel('identity', 'Submit identity'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '2',
                        title: 'PAN verification',
                        children: [
                          TextField(
                              controller: _panNumber,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                  labelText: 'PAN number')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _panName,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Name on PAN')),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: () =>
                                  _pickDocument((doc) => _panDocument = doc),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(
                                  _panDocument?.name ?? 'Choose PAN document')),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed: _isBusy('pan') ? null : _submitPan,
                              child: Text(_buttonLabel('pan', 'Submit PAN'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '3',
                        title: 'Selfie / profile photo',
                        children: [
                          const Text(
                              'Upload a current JPG or PNG photo for safety review and profile matching.',
                              style: TextStyle(color: BrandColors.muted)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: () =>
                                  _pickDocument((doc) => _profilePhoto = doc),
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label:
                                  Text(_profilePhoto?.name ?? 'Choose photo')),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed:
                                  _isBusy('photo') ? null : _submitProfilePhoto,
                              child:
                                  Text(_buttonLabel('photo', 'Submit photo'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '4',
                        title: 'Address verification',
                        children: [
                          const Text(
                              'Add address details and upload address proof as PDF, JPG or PNG.',
                              style: TextStyle(color: BrandColors.muted)),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _currentAddress,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Current address')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _permanentAddress,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Permanent address')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _city,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'City')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _state,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'State')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _pinCode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                  labelText: 'PIN code', counterText: '')),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: () => _pickDocument(
                                  (doc) => _addressDocument = doc),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(_addressDocument?.name ??
                                  'Choose address proof')),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed:
                                  _isBusy('address') ? null : _saveAddress,
                              child: Text(_buttonLabel(
                                  'address', 'Submit address and proof'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '5',
                        title: 'Police verification',
                        children: [
                          const Text(
                              'Upload police verification certificate or acknowledgement where available for your city/state.',
                              style: TextStyle(color: BrandColors.muted)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: () =>
                                  _pickDocument((doc) => _policeDocument = doc),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(_policeDocument?.name ??
                                  'Choose police document')),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed: _isBusy('police')
                                  ? null
                                  : _submitPoliceVerification,
                              child: Text(_buttonLabel(
                                  'police', 'Submit police verification'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '6',
                        title: 'Service readiness',
                        children: [
                          TextField(
                              controller: _services,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Services offered')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _workLocations,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Preferred work locations')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _experience,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Experience')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _availableWhen,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Availability')),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _partnerCodeAccepted,
                            onChanged: (value) => setState(
                                () => _partnerCodeAccepted = value ?? false),
                            title: const Text(
                                'I accept the Partner code of conduct and customer privacy rules.'),
                          ),
                          FilledButton(
                              onPressed: _isBusy('readiness')
                                  ? null
                                  : _saveServiceReadiness,
                              child: Text(
                                  _buttonLabel('readiness', 'Save readiness'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '7',
                        title: 'Payout details',
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'BANK',
                                  icon: Icon(Icons.account_balance_outlined),
                                  label: Text('Bank')),
                              ButtonSegment(
                                  value: 'UPI',
                                  icon: Icon(Icons.qr_code_2_outlined),
                                  label: Text('UPI')),
                            ],
                            selected: {_payoutMethod},
                            onSelectionChanged: (value) =>
                                setState(() => _payoutMethod = value.first),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _accountHolderName,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Account holder name')),
                          const SizedBox(height: 12),
                          if (_payoutMethod == 'BANK') ...[
                            TextField(
                                controller: _last4,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                    labelText: 'Final four account digits',
                                    counterText: '')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _ifsc,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                    labelText: 'IFSC code')),
                          ] else
                            TextField(
                                controller: _upiId,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    const InputDecoration(labelText: 'UPI ID')),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: _isBusy('payout') ? null : _savePayout,
                              child: Text(_buttonLabel(
                                  'payout', 'Save payout details'))),
                        ],
                      ),
                      _PartnerFormCard(
                        number: '8',
                        title: 'Start receiving jobs',
                        children: [
                          Text(
                            readyForJobs
                                ? 'All checks are approved. You can go available now.'
                                : 'This only succeeds after Ops approves every required compliance, safety and payout item.',
                            style: const TextStyle(color: BrandColors.muted),
                          ),
                          const SizedBox(height: 12),
                          _PartnerStatusCard(
                              title: 'Job availability',
                              status: profile?['availability']?.toString() ??
                                  'OFFLINE',
                              icon: Icons.work_outline),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed:
                                _isBusy('available') ? null : _setAvailable,
                            icon: const Icon(Icons.toggle_on_outlined),
                            label:
                                Text(_buttonLabel('available', 'Go available')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loading ? null : _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh status'),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _status(String key) => _profile?[key]?.toString() ?? 'NOT_SUBMITTED';
  bool _isBusy(String action) => _busyAction == action;
  String _buttonLabel(String action, String label) =>
      _isBusy(action) ? 'Saving...' : label;
}

class _PartnerFormCard extends StatelessWidget {
  const _PartnerFormCard(
      {required this.number, required this.title, required this.children});

  final String number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(number: number, title: title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PartnerConsentScreen extends StatelessWidget {
  const _PartnerConsentScreen({
    required this.partnerName,
    required this.saving,
    required this.onAccept,
  });

  final String partnerName;
  final bool saving;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.privacy_tip_outlined,
              color: BrandColors.lime, size: 48),
          const SizedBox(height: 20),
          Text('Before you start, $partnerName',
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(
              'Please review and accept how MaidItQuick will use your information for Partner onboarding.',
              style: TextStyle(color: BrandColors.muted, height: 1.4)),
          const SizedBox(height: 28),
          const _ConsentPoint(
              icon: Icons.badge_outlined,
              title: 'Identity and safety review',
              body:
                  'We collect identity documents, PAN, selfie, address proof and police verification only to review Partner eligibility.'),
          const _ConsentPoint(
              icon: Icons.account_balance_outlined,
              title: 'Payout setup',
              body:
                  'We collect bank or UPI details so payouts can be reviewed and configured after approval.'),
          const _ConsentPoint(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Operations access',
              body:
                  'MaidItQuick operations reviewers can approve, reject or request resubmission for required checks.'),
          const _ConsentPoint(
              icon: Icons.edit_note_outlined,
              title: 'Correction and deletion',
              body:
                  'You can request correction or deletion through support, subject to operational and legal retention needs.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onAccept,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(saving ? 'Saving...' : 'I agree and continue'),
          ),
        ],
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BrandColors.lime),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body,
                  style:
                      const TextStyle(color: BrandColors.muted, height: 1.35)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.action,
      required this.onTap,
      this.outlined = false,
      this.compact = false});
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
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: compact ? 18 : 20)),
          SizedBox(height: compact ? 4 : 6),
          Text(subtitle,
              style: TextStyle(
                  color: BrandColors.muted,
                  height: 1.3,
                  fontSize: compact ? 13 : 14)),
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

class _PartnerStatusCard extends StatelessWidget {
  const _PartnerStatusCard(
      {required this.title, required this.status, required this.icon});
  final String title;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED' || status == 'AVAILABLE';
    final pending = status == 'PENDING';
    final color = approved
        ? BrandColors.lime
        : pending
            ? Colors.amber
            : BrandColors.muted;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(status.replaceAll('_', ' '),
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(
      {required this.icon, required this.label, this.compact = false});
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: BrandColors.lime, size: compact ? 20 : 24),
        SizedBox(height: compact ? 4 : 8),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: BrandColors.muted, fontSize: compact ? 11 : 14)),
      ]);
}

class _PhoneInputFormatter extends TextInputFormatter {
  const _PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      final digit = _digitForRune(rune);
      if (digit != null) {
        buffer.write(digit);
      } else if (rune == 43 && buffer.isEmpty) {
        buffer.write('+');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _AsciiDigitInputFormatter extends TextInputFormatter {
  const _AsciiDigitInputFormatter({this.maxLength});

  final int? maxLength;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      final digit = _digitForRune(rune);
      if (digit == null) continue;
      if (maxLength != null && buffer.length >= maxLength!) break;
      buffer.write(digit);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String? _digitForRune(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return String.fromCharCode(rune);
  for (final start in [0x0660, 0x06F0, 0x0966, 0x09E6, 0x0A66, 0x0AE6]) {
    if (rune >= start && rune <= start + 9) {
      return String.fromCharCode(0x30 + rune - start);
    }
  }
  return null;
}

String _displayDate(DateTime dateTime) {
  final hour =
      dateTime.hour == 0 || dateTime.hour == 12 ? 12 : dateTime.hour % 12;
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
}

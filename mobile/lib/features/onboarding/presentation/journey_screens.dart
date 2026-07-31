import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../core/document_picker.dart';
import '../../../shared/widgets/brand_primary_button.dart';
import '../../../shared/widgets/otp_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/data/customer_addresses_repository.dart';
import '../../booking/data/service_catalog_repository.dart';
import '../../profile/presentation/complete_profile_screen.dart';

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
                  'Sign in with your mobile number, add your address and book a service.',
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
  final Future<void> Function(Session session) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerDetailsFormKey = GlobalKey<FormState>();
  final _customerOtpFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _customerOtp = TextEditingController();
  final _customerName = TextEditingController();
  OtpChallenge? _partnerChallenge;
  OtpChallenge? _customerChallenge;
  Timer? _customerOtpTimer;
  int _customerOtpSecondsRemaining = 0;
  _CountryCode _customerCountry = _customerCountries.first;
  bool _isRegistering = true;
  bool _isCustomerRegistering = false;
  bool _submitting = false;
  bool _verified = false;
  String _otpCode = '';
  Key _otpBoxesKey = UniqueKey();

  @override
  void dispose() {
    _customerOtpTimer?.cancel();
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    _customerOtp.dispose();
    _customerName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.role == UserRole.partner) {
      await _submitPartner();
      return;
    }
    await _submitCustomer();
  }

  Future<void> _submitCustomer() async {
    final challenge = _customerChallenge;
    final form = challenge == null
        ? _customerDetailsFormKey
        : _customerOtpFormKey;
    if (!form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repository = AuthRepository(widget.api);
      final phone = _e164CustomerPhone(_phone.text.trim());
      if (challenge == null) {
        final next = await repository.sendOtp(phone: phone);
        if (!mounted) return;
        setState(() {
          _customerChallenge = next;
          _otpCode = '';
          _otpBoxesKey = UniqueKey();
        });
        _startCustomerOtpTimer(next.expiresInSeconds);
        _showMessage('OTP sent to ${next.phone}.');
      } else {
        final result = await repository.verifyOtp(
          phone: challenge.phone,
          otp: _otpCode,
        );
        if (!mounted) return;
        final session = result.session;
        setState(() => _verified = true);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        if (session != null) {
          await widget.onAuthenticated(session);
          return;
        }
        final pendingToken = result.pendingToken;
        if (pendingToken == null || pendingToken.isEmpty) {
          setState(() => _verified = false);
          _showMessage('Could not complete verification. Try again.');
          return;
        }
        final created = await Navigator.of(context).push<Session>(
          MaterialPageRoute(
            builder: (context) => CompleteProfileScreen(
              api: widget.api,
              phone: result.phone,
              pendingToken: pendingToken,
              initialName: _isCustomerRegistering
                  ? _customerName.text.trim()
                  : '',
            ),
          ),
        );
        if (created != null && mounted) {
          await widget.onAuthenticated(created);
        }
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
        await widget.onAuthenticated(session);
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

  void _changeCustomerPhone() {
    _customerOtpTimer?.cancel();
    setState(() {
      _customerChallenge = null;
      _customerOtpSecondsRemaining = 0;
      _otpCode = '';
      _verified = false;
      _otpBoxesKey = UniqueKey();
    });
    _customerOtp.clear();
  }

  Future<void> _resendCustomerOtp() async {
    final challenge = _customerChallenge;
    if (challenge == null) return;
    setState(() => _submitting = true);
    try {
      final repository = AuthRepository(widget.api);
      final next = await repository.sendOtp(phone: challenge.phone);
      if (!mounted) return;
      setState(() {
        _customerChallenge = next;
        _otpCode = '';
        _otpBoxesKey = UniqueKey();
      });
      _customerOtp.clear();
      _startCustomerOtpTimer(next.expiresInSeconds);
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

  void _toggleCustomerMode() {
    _customerOtpTimer?.cancel();
    setState(() {
      _isCustomerRegistering = !_isCustomerRegistering;
      _customerChallenge = null;
      _customerOtpSecondsRemaining = 0;
      _otpCode = '';
      _verified = false;
      _otpBoxesKey = UniqueKey();
    });
    _customerOtp.clear();
    _customerName.clear();
  }

  void _handleCustomerBack() {
    if (_submitting) return;
    if (_customerChallenge != null) {
      _changeCustomerPhone();
      return;
    }
    widget.onBack();
  }

  void _handleAuthBack() {
    if (_submitting) return;
    if (widget.role == UserRole.customer && _customerChallenge != null) {
      _changeCustomerPhone();
      return;
    }
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

  void _startCustomerOtpTimer(int seconds) {
    _customerOtpTimer?.cancel();
    setState(() => _customerOtpSecondsRemaining = seconds);
    _customerOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_customerOtpSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _customerOtpSecondsRemaining = 0);
        return;
      }
      setState(() => _customerOtpSecondsRemaining--);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == UserRole.partner) return _buildPartnerAuth();
    return _buildCustomerAuth();
  }

  Widget _buildCustomerAuth() {
    final challenge = _customerChallenge;
    final awaitingOtp = challenge != null;
    final compact = MediaQuery.sizeOf(context).height < 780;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: _submitting ? null : _handleCustomerBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back'),
        title: const Text('Customer'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, compact ? 10 : 20, 20, 24),
              children: [
                _AuthBrandHeader(
                  compact: compact,
                  title: awaitingOtp
                      ? 'Verify your number'
                      : _isCustomerRegistering
                          ? 'Create your account'
                          : 'Welcome to MaidItQuick',
                  subtitle: awaitingOtp
                      ? 'We sent a six-digit code to ${_maskPhone(challenge.phone)}'
                      : _isCustomerRegistering
                          ? 'Enter your name and mobile number. We will verify it with an OTP.'
                          : 'Sign in securely with your mobile number. No passwords needed.',
                  step: awaitingOtp ? 2 : 1,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: awaitingOtp
                      ? _buildCustomerOtpCard(compact, challenge)
                      : _buildCustomerDetailsCard(compact),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsCard(bool compact) {
    return Card(
      key: const ValueKey('customer-details'),
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 26),
        child: Form(
          key: _customerDetailsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.login_outlined),
                      label: Text('Sign in')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.person_add_alt_1_outlined),
                      label: Text('Sign up')),
                ],
                selected: {_isCustomerRegistering},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => _toggleCustomerMode(),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 20),
              if (_isCustomerRegistering) ...[
                TextFormField(
                  controller: _customerName,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter your full name'
                          : null,
                ),
                const SizedBox(height: 14),
              ],
              DropdownButtonFormField<_CountryCode>(
                initialValue: _customerCountry,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
                items: _customerCountries
                    .map((country) => DropdownMenuItem<_CountryCode>(
                          value: country,
                          child: Text('${country.name} (${country.code})'),
                        ))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (country) {
                        if (country == null) return;
                        setState(() {
                          _customerCountry = country;
                          _phone.clear();
                        });
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [
                  AutofillHints.telephoneNumberNational
                ],
                inputFormatters: [
                  _NationalNumberInputFormatter(
                      _customerCountry.nationalDigits)
                ],
                decoration: InputDecoration(
                  labelText: 'Mobile number',
                  helperText:
                      '${_customerCountry.nationalDigits}-digit number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '${_customerCountry.code} ',
                ),
                validator: _validateCustomerPhone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              BrandPrimaryButton(
                onPressed: _submitting || !_customerPhoneValid
                    ? null
                    : _submit,
                icon: Icons.sms_outlined,
                label: 'Send OTP',
                busy: _submitting,
              ),
              const SizedBox(height: 12),
              _AuthTermsRow(onShowMessage: _showMessage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerOtpCard(bool compact, OtpChallenge challenge) {
    final resendLabel = _customerOtpSecondsRemaining > 0
        ? 'Resend in ${_customerOtpSecondsRemaining}s'
        : 'Resend OTP';
    return Card(
      key: const ValueKey('customer-otp'),
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 26),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _verified
              ? const _OtpSuccessView(key: ValueKey('otp-success'))
              : Form(
                  key: _customerOtpFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: context.scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sms_outlined,
                              color: context.scheme.primary, size: 30),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'Code sent to ${_maskPhone(challenge.phone)}',
                          style: TextStyle(
                              fontSize: compact ? 15 : 17,
                              fontWeight: FontWeight.w700,
                              color: context.scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 22),
                      OtpTextField(
                        key: _otpBoxesKey,
                        controller: _customerOtp,
                        helperText: challenge.devOtp == null
                            ? 'Enter the six-digit code.'
                            : 'Dev OTP: ${challenge.devOtp}',
                        onChanged: (value) {
                          _otpCode = value;
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed:
                                  _submitting ? null : _changeCustomerPhone,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Change number'),
                            ),
                          ),
                          TextButton(
                            onPressed: _submitting ||
                                    _customerOtpSecondsRemaining > 0
                                ? null
                                : _resendCustomerOtp,
                            child: Text(resendLabel),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      BrandPrimaryButton(
                        onPressed: _submitting || _otpCode.length != 6
                            ? null
                            : _submit,
                        icon: Icons.verified_user_outlined,
                        label: 'Verify and continue',
                        busy: _submitting,
                        busyLabel: 'Verifying...',
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _e164CustomerPhone(String raw) =>
      '${_customerCountry.code}${raw.replaceAll(RegExp(r'\D'), '')}';

  bool get _customerPhoneValid =>
      _phone.text.trim().replaceAll(RegExp(r'\D'), '').length ==
      _customerCountry.nationalDigits;

  String? _validateCustomerPhone(String? value) {
    final digits = (value ?? '').trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != _customerCountry.nationalDigits) {
      return _customerCountry.code == '+91'
          ? 'Enter a valid 10-digit mobile number'
          : 'Enter a ${_customerCountry.nationalDigits}-digit mobile number';
    }
    return null;
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
              BrandPrimaryButton(
                onPressed: _submitting ? null : _submit,
                label: challenge == null
                    ? (_isRegistering ? 'Continue' : 'Send OTP')
                    : 'Verify and continue',
                busy: _submitting,
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
      final minutes =
          await ServiceCatalogRepository(widget.api).calculateDuration(selected);
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
          defaultAddress: makeDefault || _addresses.isEmpty || _editingAddressId == null);
      final repository = CustomerAddressesRepository(widget.api);
      final saved = _editingAddressId == null
          ? await repository.create(widget.session.token, payload)
          : await repository.update(
              widget.session.token, _editingAddressId!, payload);
      if (!mounted) return;
      setState(() {
        if (_editingAddressId == null) {
          _addresses = [saved.toMap(), ..._addresses.where((item) => item['id'] != saved.id)];
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CustomerAddressesRepository(widget.api)
          .delete(widget.session.token, (address['id'] as num).toInt());
      if (!mounted) return;
      setState(() {
        _addresses = _addresses.where((item) => item['id'] != address['id']).toList();
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
    final slot = _timeSlots.contains(currentSlot)
        ? currentSlot
        : _timeSlots.first;
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
                            .map((address) => Card(
                                  child: Column(
                                    children: [
                                      RadioListTile<Map<String, dynamic>>(
                                        value: address,
                                        activeColor: BrandColors.lime,
                                        title: Row(
                                          children: [
                                            Expanded(
                                                child: Text(
                                                    address['label']?.toString() ??
                                                        'Address')),
                                            if (address['defaultAddress'] == true)
                                              const Chip(
                                                  label: Text('Default'),
                                                  visualDensity:
                                                      VisualDensity.compact),
                                          ],
                                        ),
                                        subtitle: Text(
                                            '${address['address']}\n${address['pinCode']}',
                                            style: const TextStyle(
                                                color: BrandColors.muted)),
                                      ),
                                      OverflowBar(
                                        alignment: MainAxisAlignment.end,
                                        spacing: 4,
                                        children: [
                                          TextButton(
                                              onPressed: () =>
                                                  _startEditingAddress(address),
                                              child: const Text('Edit')),
                                          TextButton(
                                              onPressed: address['defaultAddress'] ==
                                                      true
                                                  ? null
                                                  : () => _setDefaultAddress(
                                                      address),
                                              child: const Text('Set default')),
                                          TextButton(
                                              onPressed: () =>
                                                  _deleteAddress(address),
                                              child: const Text('Delete')),
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
                      decoration:
                          const InputDecoration(labelText: 'Landmark (optional)')),
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
                    decoration: const InputDecoration(
                        labelText: 'PIN code', counterText: ''),
                    onChanged: (_) => setState(() => _availability = null),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingAddress ? null : () => _saveAddress(),
                        icon: const Icon(Icons.add_location_alt_outlined),
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
                        final name = service['name']?.toString() ?? '';
                        final selected = _selectedServices.contains(name);
                        final price =
                            ((service['pricePaise'] ?? 0) as num) ~/ 100;
                        return FilterChip(
                          selected: selected,
                          showCheckmark: true,
                          avatar: const Icon(Icons.cleaning_services_outlined,
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
                      final selected = TimeOfDay.fromDateTime(_scheduled) == slot;
                      final available = _slotAvailable(slot);
                      return ChoiceChip(
                        selected: selected,
                        label: Text(_slotLabel(slot)),
                        onSelected:
                            available ? (_) => _selectSlot(slot) : null,
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
                    label: Text(
                        _booking ? 'Requesting...' : 'Review booking'),
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

class _CountryCode {
  const _CountryCode(this.code, this.name, this.nationalDigits);

  final String code;
  final String name;
  final int nationalDigits;
}

const List<_CountryCode> _customerCountries = [
  _CountryCode('+91', 'India', 10),
  _CountryCode('+971', 'United Arab Emirates', 9),
  _CountryCode('+1', 'United States', 10),
  _CountryCode('+44', 'United Kingdom', 9),
  _CountryCode('+61', 'Australia', 9),
];

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.step,
  });

  final bool compact;
  final String title;
  final String subtitle;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'assets/branding/maiditquick-wordmark.jpeg',
            height: compact ? 62 : 88,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: compact ? 16 : 26),
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: context.brandMuted,
            height: 1.4,
            fontSize: compact ? 13 : 15,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _AuthStepPill(index: 1, label: 'Mobile number', active: step >= 1),
            const SizedBox(width: 10),
            _AuthStepPill(index: 2, label: 'Verify OTP', active: step >= 2),
          ],
        ),
      ],
    );
  }
}

class _AuthStepPill extends StatelessWidget {
  const _AuthStepPill({
    required this.index,
    required this.label,
    required this.active,
  });

  final int index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final foreground = active ? scheme.onPrimary : scheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: active ? scheme.onPrimary : Colors.transparent,
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTermsRow extends StatelessWidget {
  const _AuthTermsRow({required this.onShowMessage});

  final ValueChanged<String> onShowMessage;

  @override
  Widget build(BuildContext context) {
    final muted = context.brandMuted;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing, you agree to ',
            style: TextStyle(color: muted, fontSize: 12)),
        TextButton(
          onPressed: () => onShowMessage('Terms will open in production.'),
          child: const Text('Terms'),
        ),
        Text(' and ', style: TextStyle(color: muted, fontSize: 12)),
        TextButton(
          onPressed: () =>
              onShowMessage('Privacy policy will open in production.'),
          child: const Text('Privacy'),
        ),
      ],
    );
  }
}

class _OtpSuccessView extends StatelessWidget {
  const _OtpSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: scheme.primary, size: 44),
          ),
          const SizedBox(height: 18),
          Text(
            'Verified!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Signing you in...',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _NationalNumberInputFormatter extends TextInputFormatter {
  const _NationalNumberInputFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      final digit = _digitForRune(rune);
      if (digit == null) continue;
      if (buffer.length >= maxLength) break;
      buffer.write(digit);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
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

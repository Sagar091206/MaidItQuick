import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/brand_primary_button.dart';
import '../../../shared/widgets/otp_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/presentation/complete_profile_screen.dart';

/// Renders the development OTP hint only in debug builds so a shipped app
/// never reveals codes in the UI.
String _otpHelperText(OtpChallenge challenge, String fallback) {
  if (challenge.devOtp == null) return fallback;
  return kDebugMode ? 'Dev OTP: ${challenge.devOtp}' : fallback;
}
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
    final form =
        challenge == null ? _customerDetailsFormKey : _customerOtpFormKey;
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
              initialName:
                  _isCustomerRegistering ? _customerName.text.trim() : '',
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
                  label: Text('Sign in'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.person_add_alt_1_outlined),
                  label: Text('Sign up'),
                ),
              ],
              selected: {_isCustomerRegistering},
              onSelectionChanged:
                  _submitting ? null : (selection) => _toggleCustomerMode(),
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
                  .where((country) => country.code == '+91')
                  .map(
                    (country) => DropdownMenuItem<_CountryCode>(
                      value: country,
                      child: Text('${country.name} (${country.code})'),
                    ),
                  )
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
                AutofillHints.telephoneNumberNational,
              ],
              inputFormatters: [
                _NationalNumberInputFormatter(
                  _customerCountry.nationalDigits,
                ),
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
              onPressed:
                  _submitting || !_customerPhoneValid ? null : _submit,
              icon: Icons.sms_outlined,
              label: 'Send OTP',
              busy: _submitting,
            ),

            const SizedBox(height: 12),

            _AuthTermsRow(
              onShowMessage: _showMessage,
            ),
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
                        helperText: _otpHelperText(
                            challenge, 'Enter the six-digit code.'),
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
                            onPressed:
                                _submitting || _customerOtpSecondsRemaining > 0
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
                    helperText: _otpHelperText(
                        challenge, 'Code expires in 10 minutes.'),
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


import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/services/profile_photo_picker.dart';
import '../../../shared/widgets/onboarding_bottom_bar.dart';
import '../../../shared/widgets/onboarding_step_card.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/customer_profile_repository.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.api,
    required this.session,
    required this.initialProfile,
    required this.requiredSetup,
    this.onSaved,
  });

  final ApiClient api;
  final Session session;
  final CustomerProfile? initialProfile;
  final bool requiredSetup;
  final Future<void> Function(CustomerProfile profile)? onSaved;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phoneDisplay;
  DateTime? _dob;
  String? _gender;
  String? _profileImage;
  bool _submitting = false;

  static const _genderOptions = [
    ('MALE', 'Male'),
    ('FEMALE', 'Female'),
    ('OTHER', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _name = TextEditingController(text: profile?.name ?? '');
    _email = TextEditingController(text: profile?.email ?? '');
    _phoneDisplay =
        TextEditingController(text: _formatPhone(profile?.phone ?? ''));
    _dob = _parseDob(profile?.dob ?? '');
    _gender = profile?.gender.isEmpty ?? true ? null : profile!.gender;
    _profileImage =
        (profile?.profileImage.isEmpty ?? true) ? null : profile!.profileImage;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phoneDisplay.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _name.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatPhone(String phone) {
    if (phone.startsWith('+91') && phone.length == 13) {
      return '+91 ${phone.substring(3)}';
    }
    return phone;
  }

  DateTime? _parseDob(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _dobPayload() {
    final dob = _dob;
    if (dob == null) return '';
    return '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
  }

  String _dobLabel() {
    final dob = _dob;
    if (dob == null) return 'Date of birth (required)';
    return '${dob.day}/${dob.month}/${dob.year}';
  }

  Future<void> _pickDob() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(today.year - 100, 1, 1),
      lastDate: DateTime(today.year - 13, today.month, today.day),
    );
    if (selected != null && mounted) setState(() => _dob = selected);
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await pickProfilePhotoDataUri();
      if (photo != null && mounted) setState(() => _profileImage = photo);
    } catch (_) {
      _showMessage('Could not open the photo gallery.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _showMessage('Date of birth is required.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final saved = await CustomerProfileRepository(widget.api).save(
        token: widget.session.token,
        name: _name.text.trim(),
        email: _email.text.trim(),
        gender: _gender,
        dob: _dobPayload(),
        profileImage: _profileImage,
      );
      if (!mounted) return;
      if (widget.onSaved != null) {
        await widget.onSaved!(saved);
      } else {
        Navigator.of(context).pop(saved);
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to save profile right now.');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    final theme = Theme.of(context);
    final title = widget.requiredSetup ? 'Create your profile' : 'Edit profile';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.requiredSetup,
        title: Text(title),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.requiredSetup
                        ? 'Complete your profile before you book.'
                        : 'Keep your details up to date.',
                    style:
                        const TextStyle(color: BrandColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  OnboardingStepCard(
                    number: '1',
                    title: 'Profile details',
                    status: widget.requiredSetup ? 'REQUIRED' : 'IN PROGRESS',
                    initiallyExpanded: true,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            ProfileAvatar(
                              initials: _initials,
                              photoDataUri: _profileImage,
                              radius: 44,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: theme.colorScheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _submitting ? null : _pickPhoto,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.photo_camera_outlined,
                                        size: 18,
                                        color: theme.colorScheme.onPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: _submitting ? null : _pickPhoto,
                          child: const Text('Change photo'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _name,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.words,
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
                      TextFormField(
                        readOnly: true,
                        controller: _phoneDisplay,
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          helperText: 'Verified during sign in',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return null;
                          return email.contains('@')
                              ? null
                              : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: _genderOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.$1,
                                child: Text(option.$2),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select your gender' : null,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _gender = value),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickDob,
                        icon: const Icon(Icons.cake_outlined),
                        label: Text(_dobLabel()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            OnboardingBottomBar(
              child: FilledButton(
                onPressed: _submitting ? null : _save,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: BrandColors.evergreen))
                    : Text(widget.requiredSetup ? 'Save and continue' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

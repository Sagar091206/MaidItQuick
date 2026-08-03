import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/services/profile_photo_picker.dart';
import '../../../shared/widgets/onboarding_bottom_bar.dart';
import '../../../shared/widgets/onboarding_step_card.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../auth/data/auth_repository.dart';

/// Profile completion for a brand-new customer who just verified their mobile
/// number. Sends the details to the backend, which creates the account with
/// profileCompleted set to true and returns a session.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.api,
    required this.phone,
    required this.pendingToken,
    this.initialName = '',
  });

  final ApiClient api;
  final String phone;
  final String pendingToken;
  final String initialName;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final _email = TextEditingController();
  String? _gender;
  DateTime? _dob;
  String? _profileImage;
  bool _submitting = false;

  static const _genderOptions = [
    ('MALE', 'Male'),
    ('FEMALE', 'Female'),
    ('OTHER', 'Other'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
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
      initialDate: DateTime(today.year - 25, today.month, today.day),
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
      final session = await AuthRepository(widget.api).completeProfile(
        pendingToken: widget.pendingToken,
        name: _name.text.trim(),
        email: _email.text.trim(),
        gender: _gender,
        dob: _dobPayload(),
        profileImage: _profileImage,
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not create your account right now.');
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

  String get _initials {
    final name = _name.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  const Text(
                    'Create your account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us a little about yourself. Your number ${widget.phone} is already verified.',
                    style: const TextStyle(
                        color: BrandColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  OnboardingStepCard(
                    number: '1',
                    title: 'Profile details',
                    status: 'REQUIRED',
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
                          child: const Text('Add a profile photo'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _name,
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
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
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
              child: FilledButton.icon(
                onPressed: _submitting ? null : _save,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: BrandColors.evergreen),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _submitting ? 'Creating account...' : 'Create my account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

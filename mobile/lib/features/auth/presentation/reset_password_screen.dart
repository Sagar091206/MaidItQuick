import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/utils/password_validator.dart';
import '../data/auth_repository.dart';

/// Screen for the "Forgot Password → New Password" step.
///
/// Implements real-time password strength / requirement validation:
/// - Minimum 8 characters
/// - At least 1 uppercase letter (A-Z)
/// - At least 1 lowercase letter (a-z)
/// - At least 1 number (0-9)
/// - At least 1 special character (!@#$%^&*)
///
/// The "Reset Password" button remains disabled until all 5 requirements
/// are satisfied and the confirm password field matches.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.api,
    this.initialToken = '',
    this.onSuccess,
    this.onBackToLogin,
  });

  final ApiClient api;
  final String initialToken;
  final VoidCallback? onSuccess;
  final VoidCallback? onBackToLogin;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _tokenController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _success = false;
  String? _errorMessage;

  PasswordRequirementState _requirements = PasswordRequirementState.empty;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _requirements = PasswordRequirementState.evaluate(value);
      _errorMessage = null;
    });
  }

  void _onConfirmChanged(String value) {
    setState(() {
      _errorMessage = null;
    });
  }

  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  bool get _canSubmit {
    return _requirements.allSatisfied &&
        _passwordsMatch &&
        _tokenController.text.trim().isNotEmpty &&
        !_submitting;
  }

  Future<void> _handleReset() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final repo = AuthRepository(widget.api);
      await repo.resetPassword(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _success = true;
        });
        widget.onSuccess?.call();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Unable to reset password. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: widget.onBackToLogin != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToLogin,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _success ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: BrandColors.lime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 50, color: BrandColors.lime),
          ),
          const SizedBox(height: 24),
          const Text(
            'Password Changed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your password has been updated successfully. You can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.lime,
                foregroundColor: BrandColors.evergreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: widget.onBackToLogin ?? () => Navigator.of(context).pop(),
              child: const Text(
                'Back to Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final hasConfirmText = _confirmController.text.isNotEmpty;
    final showMismatchError = hasConfirmText && !_passwordsMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set a new password',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a strong password with at least 8 characters, including numbers and symbols.',
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Reset Token field (if not provided as fixed token)
        if (widget.initialToken.isEmpty) ...[
          const Text('Reset Token',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter the reset token received via email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: 18),
        ],

        // New Password Field
        const Text('New password',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('new_password_field'),
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: _onPasswordChanged,
          decoration: InputDecoration(
            hintText: 'Enter new password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              key: const Key('toggle_password_visibility'),
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Real-Time Requirements Checklist
        Container(
          key: const Key('password_requirements_box'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff121815)
                : const Color(0xfff8faf9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff1a241e)
                  : const Color(0xffe2e8f0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password requirements:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _RequirementRow(
                key: const Key('req_min_length'),
                satisfied: _requirements.hasMinLength,
                label: 'Minimum 8 characters',
              ),
              _RequirementRow(
                key: const Key('req_uppercase'),
                satisfied: _requirements.hasUppercase,
                label: 'At least 1 uppercase letter (A-Z)',
              ),
              _RequirementRow(
                key: const Key('req_lowercase'),
                satisfied: _requirements.hasLowercase,
                label: 'At least 1 lowercase letter (a-z)',
              ),
              _RequirementRow(
                key: const Key('req_digit'),
                satisfied: _requirements.hasDigit,
                label: 'At least 1 number (0-9)',
              ),
              _RequirementRow(
                key: const Key('req_special'),
                satisfied: _requirements.hasSpecial,
                label: 'At least 1 special character (!@#\$%^&*)',
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Confirm New Password Field
        const Text('Confirm new password',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('confirm_password_field'),
          controller: _confirmController,
          obscureText: _obscureConfirm,
          onChanged: _onConfirmChanged,
          decoration: InputDecoration(
            hintText: 'Repeat the password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              key: const Key('toggle_confirm_visibility'),
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            errorText: showMismatchError ? 'Passwords do not match' : null,
          ),
        ),

        const SizedBox(height: 28),

        // Reset Password Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('reset_password_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.lime,
              foregroundColor: BrandColors.evergreen,
              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _canSubmit ? _handleReset : null,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(BrandColors.evergreen),
                    ),
                  )
                : const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    super.key,
    required this.satisfied,
    required this.label,
  });

  final bool satisfied;
  final String label;

  @override
  Widget build(BuildContext context) {
    const satisfiedColor = BrandColors.lime;
    final unsatisfiedColor = Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${satisfied ? "✓" : "✗"} $label',
              style: TextStyle(
                fontSize: 13,
                color: satisfied ? satisfiedColor : unsatisfiedColor,
                fontWeight: satisfied ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

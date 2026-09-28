/// Platform password policy validator and requirement state model.
///
/// Enforces:
/// 1. Minimum 8 characters (up to 128)
/// 2. At least 1 uppercase letter (A-Z)
/// 3. At least 1 lowercase letter (a-z)
/// 4. At least 1 number (0-9)
/// 5. At least 1 special character (!@#$%^&*)
class PasswordRequirementState {
  const PasswordRequirementState({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecial,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecial;

  /// Returns true only when all 5 requirements are satisfied.
  bool get allSatisfied =>
      hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecial;

  /// Evaluates a password string against all 5 requirements.
  factory PasswordRequirementState.evaluate(String password) {
    return PasswordRequirementState(
      hasMinLength: password.length >= 8 && password.length <= 128,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasDigit: RegExp(r'[0-9]').hasMatch(password),
      hasSpecial: RegExp(r'[!@#$%^&*]').hasMatch(password),
    );
  }

  /// Initial empty state where no criteria are satisfied.
  static const empty = PasswordRequirementState(
    hasMinLength: false,
    hasUppercase: false,
    hasLowercase: false,
    hasDigit: false,
    hasSpecial: false,
  );
}

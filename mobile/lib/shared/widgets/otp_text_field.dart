import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six-digit one-time password input with autofocus, OTP auto-fill support,
/// digit normalization and a label/helper hint. Mirrors the letter-spaced
/// style of the auth screens while keeping the widget reusable.
class OtpTextField extends StatelessWidget {
  const OtpTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = true,
    this.helperText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: key,
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: const [AsciiDigitInputFormatter(maxLength: 6)],
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        labelText: 'One-time password',
        counterText: '',
        helperText: helperText,
      ),
      validator: (value) =>
          value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())
              ? 'Enter the six-digit OTP'
              : null,
      onChanged: (value) => onChanged(value.trim()),
    );
  }
}

/// Keeps only ASCII digits (normalizing Indic/Arabic digits) up to [maxLength].
class AsciiDigitInputFormatter extends TextInputFormatter {
  const AsciiDigitInputFormatter({this.maxLength});

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

  static String? _digitForRune(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return String.fromCharCode(rune);
    for (final start in [0x0660, 0x06F0, 0x0966, 0x09E6, 0x0A66, 0x0AE6]) {
      if (rune >= start && rune <= start + 9) {
        return String.fromCharCode(0x30 + rune - start);
      }
    }
    return null;
  }
}

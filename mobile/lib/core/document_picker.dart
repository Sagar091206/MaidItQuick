import 'package:flutter/services.dart';

/// Android's system document picker, kept in-app so partner KYC does not rely
/// on a third-party native plugin. The platform side restricts choices to the
/// formats accepted by the backend.
class KycDocumentPicker {
  KycDocumentPicker._();

  static const _channel = MethodChannel('maiditquick/kyc_document_picker');

  static Future<KycDocument?> pick() async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>('pickDocument');
      if (response == null) return null;
      final bytes = response['bytes'];
      if (bytes is! Uint8List) throw const KycDocumentPickerException('Could not read the selected document.');
      return KycDocument(
        name: response['name']?.toString() ?? 'identity-document',
        mimeType: response['mimeType']?.toString() ?? 'application/octet-stream',
        bytes: bytes,
      );
    } on PlatformException catch (error) {
      throw KycDocumentPickerException(error.message ?? 'Could not choose a document.');
    }
  }
}

class KycDocument {
  const KycDocument({required this.name, required this.mimeType, required this.bytes});

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class KycDocumentPickerException implements Exception {
  const KycDocumentPickerException(this.message);

  final String message;
}

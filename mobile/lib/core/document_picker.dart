import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Native document picker for Partner KYC uploads. The platform side restricts
/// choices to the formats accepted by the backend.
class KycDocumentPicker {
  KycDocumentPicker._();

  static const _channel = MethodChannel('maiditquick/kyc_document_picker');

  static Future<KycDocument?> pick() async {
    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>('pickDocument');
      if (response == null) return null;
      final bytes = response['bytes'];
      if (bytes is! Uint8List) {
        throw const KycDocumentPickerException(
            'Could not read the selected document.');
      }
      return KycDocument(
        name: response['name']?.toString() ?? 'identity-document',
        mimeType:
            response['mimeType']?.toString() ?? 'application/octet-stream',
        bytes: bytes,
      );
    } on PlatformException catch (error) {
      throw KycDocumentPickerException(
          error.message ?? 'Could not choose a document.');
    }
  }

  static Future<KycDocument?> pickPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (photo == null) return null;
      final bytes = await photo.readAsBytes();
      return KycDocument(
        name: photo.name.isEmpty ? 'profile-photo.jpg' : photo.name,
        mimeType: _photoMimeType(photo),
        bytes: bytes,
      );
    } on PlatformException catch (error) {
      throw KycDocumentPickerException(
          error.message ?? 'Could not choose a photo.');
    } catch (_) {
      throw const KycDocumentPickerException('Could not choose a photo.');
    }
  }

  static String _photoMimeType(XFile photo) {
    final mimeType = photo.mimeType;
    if (mimeType == 'image/png' || mimeType == 'image/jpeg') {
      return mimeType!;
    }
    final extension = photo.name.split('.').last.toLowerCase();
    return extension == 'png' ? 'image/png' : 'image/jpeg';
  }
}

class KycDocument {
  const KycDocument(
      {required this.name, required this.mimeType, required this.bytes});

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class KycDocumentPickerException implements Exception {
  const KycDocumentPickerException(this.message);

  final String message;
}

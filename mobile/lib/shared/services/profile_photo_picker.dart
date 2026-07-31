import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Picks a profile photo from the device gallery, compresses it to a small
/// JPEG (max 512px, quality 80) and returns it as a base64 data URI suitable
/// for the customer profile endpoints. Returns null when the user cancels.
Future<String?> pickProfilePhotoDataUri() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  if (bytes.isEmpty || bytes.length > 1500000) return null;
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

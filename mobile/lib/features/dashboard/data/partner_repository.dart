import '../../../core/api_client.dart';
import '../../../core/document_picker.dart';

/// Wraps the partner (worker) endpoints used by the onboarding flow and the
/// partner dashboard, so screens never hardcode API paths or token plumbing.
class PartnerRepository {
  PartnerRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> fetchProfile(String token) =>
      _asMap(_api.get('/workers/me', token: token));

  Future<Map<String, dynamic>> setAvailability(
    String token,
    String status,
  ) =>
      _asMap(_api.post(
        '/workers/me/availability',
        {'status': status},
        token: token,
      ));

  Future<Map<String, dynamic>> acceptConsent(
    String token, {
    bool accepted = true,
  }) =>
      _asMap(_api.post(
        '/workers/me/consent',
        {'accepted': accepted},
        token: token,
      ));

  Future<Map<String, dynamic>> submitIdentityDocument({
    required String token,
    required KycDocument document,
  }) =>
      _upload(token, '/workers/me/identity-document', document);

  Future<Map<String, dynamic>> submitPan({
    required String token,
    required String panNumber,
    required String panName,
    required KycDocument document,
  }) =>
      _upload(
        token,
        '/workers/me/pan',
        document,
        fields: {'panNumber': panNumber, 'panName': panName},
      );

  Future<Map<String, dynamic>> submitProfilePhoto({
    required String token,
    required KycDocument document,
  }) =>
      _upload(token, '/workers/me/profile-photo', document);

  Future<Map<String, dynamic>> saveAddress({
    required String token,
    required String currentAddress,
    required String permanentAddress,
    required String city,
    required String state,
    required String pinCode,
  }) =>
      _asMap(_api.post(
        '/workers/me/address',
        {
          'currentAddress': currentAddress,
          'permanentAddress': permanentAddress,
          'city': city,
          'state': state,
          'pinCode': pinCode,
        },
        token: token,
      ));

  Future<Map<String, dynamic>> submitAddressProof({
    required String token,
    required KycDocument document,
  }) =>
      _upload(token, '/workers/me/address-proof', document);

  Future<Map<String, dynamic>> savePayout({
    required String token,
    required String method,
    required String accountHolderName,
    required String accountNumber,
    required String ifsc,
    required String upiId,
  }) =>
      _asMap(_api.post(
        '/workers/me/payout-details',
        {
          'method': method,
          'accountHolderName': accountHolderName,
          'accountNumber': accountNumber,
          'accountLast4': accountNumber.length >= 4
              ? accountNumber.substring(accountNumber.length - 4)
              : accountNumber,
          'ifsc': ifsc,
          'upiId': upiId,
        },
        token: token,
      ));

  Future<Map<String, dynamic>> fetchBooking(String token, String bookingId) =>
      _asMap(_api.get('/bookings/$bookingId', token: token));

  Future<Map<String, dynamic>> acceptBooking(
    String token,
    String bookingId,
  ) =>
      _asMap(_api.post('/bookings/$bookingId/accept', const {}, token: token));

  Future<Map<String, dynamic>> rejectBooking(
    String token,
    String bookingId, {
    String? reason,
  }) =>
      _asMap(_api.post(
        '/bookings/$bookingId/reject',
        {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
        token: token,
      ));

  Future<Map<String, dynamic>> startJourney(String token, String bookingId) =>
      _asMap(_api.post('/bookings/$bookingId/on-the-way', const {}, token: token));

  Future<Map<String, dynamic>> requestContactToken(
    String token,
    String bookingId,
  ) =>
      _asMap(_api.post(
        '/bookings/$bookingId/contact-token',
        const {},
        token: token,
      ));

  Future<Map<String, dynamic>> cancelBooking(
    String token,
    String bookingId, {
    String? reason,
  }) =>
      _asMap(_api.post(
        '/bookings/$bookingId/cancel',
        {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
        token: token,
      ));

  Future<Map<String, dynamic>> _upload(
    String token,
    String endpoint,
    KycDocument document, {
    Map<String, String> fields = const {},
  }) =>
      _asMap(_api.multipartPost(
        endpoint,
        token: token,
        bytes: document.bytes,
        fileName: document.name,
        mimeType: document.mimeType,
        fields: fields,
      ));

  Future<Map<String, dynamic>> _asMap(Future<dynamic> request) async {
    final payload = await request;
    return payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
  }
}

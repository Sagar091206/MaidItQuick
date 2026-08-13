import '../../../core/api_client.dart';

/// Wraps the mobile support-ticket endpoints so screens never hardcode API
/// paths or token plumbing.
class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> fetchMyTickets(String token) async {
    final payload = await _api.get('/support/tickets/mine', token: token);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createTicket(
    String token, {
    required String subject,
    required String message,
  }) async {
    final payload = await _api.post(
      '/support/tickets',
      {
        'subject': subject.trim(),
        'message': message.trim(),
      },
      token: token,
    );
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }
}
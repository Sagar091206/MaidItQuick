import '../../../core/api_client.dart';

/// Wraps the mobile notification-inbox endpoints.
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> fetchNotifications(String token) async {
    final payload = await _api.get('/notifications', token: token);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> markRead(
    String token,
    String notificationId,
  ) async {
    final payload = await _api.post(
      '/notifications/$notificationId/read',
      const {},
      token: token,
    );
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> markAllRead(String token) async {
    final payload = await _api.post(
      '/notifications/read-all',
      const {},
      token: token,
    );
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }
}
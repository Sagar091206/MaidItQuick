import '../../../core/api_client.dart';

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<List<CustomerNotification>> list(String token) async {
    final payload = await _api.get('/notifications', token: token) as List;
    return payload
        .whereType<Map>()
        .map((item) =>
            CustomerNotification.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CustomerNotification> markRead(String token, int id) async {
    final payload = Map<String, dynamic>.from(await _api.post(
      '/notifications/$id/read',
      const {},
      token: token,
    ) as Map);
    return CustomerNotification.fromJson(payload);
  }
}

class CustomerNotification {
  const CustomerNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.message,
      required this.read,
      required this.createdAt,
      this.bookingId});

  factory CustomerNotification.fromJson(Map<String, dynamic> json) =>
      CustomerNotification(
        id: (json['id'] as num).toInt(),
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: json['createdAt']?.toString() ?? '',
        bookingId: (json['bookingId'] as num?)?.toInt(),
      );

  final int id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final String createdAt;
  final int? bookingId;

  bool get containsOtp =>
      title.toLowerCase().contains('otp') ||
      RegExp(r'\b\d{6}\b').hasMatch(message);
  String? get otp => RegExp(r'\b\d{6}\b').firstMatch(message)?.group(0);
}

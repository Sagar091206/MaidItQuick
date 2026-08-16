import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/features/notifications/data/notification_repository.dart';

void main() {
  test('recognizes and extracts a six-digit service OTP', () {
    final alert = CustomerNotification.fromJson({
      'id': 14,
      'type': 'BOOKING',
      'title': 'Start-service OTP',
      'message': 'Share this OTP only after arrival: 042731',
      'read': false,
      'createdAt': '2026-08-13T12:00:00Z',
      'bookingId': 9,
    });

    expect(alert.containsOtp, isTrue);
    expect(alert.otp, '042731');
    expect(alert.bookingId, 9);
    expect(alert.read, isFalse);
  });

  test('ordinary booking alerts do not expose an OTP', () {
    final alert = CustomerNotification.fromJson({
      'id': 15,
      'type': 'BOOKING',
      'title': 'Worker assigned',
      'message': 'A verified worker has been assigned.',
      'read': true,
      'createdAt': '2026-08-13T12:00:00Z',
    });

    expect(alert.containsOtp, isFalse);
    expect(alert.otp, isNull);
  });
}

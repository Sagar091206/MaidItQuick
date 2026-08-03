import '../../../core/api_client.dart';
import '../../booking/data/booking_repository.dart';

class InstantBookingRepository {
  InstantBookingRepository(this._api);
  final ApiClient _api;

  Future<CustomerBooking> create(String token,
      {required int addressId,
      required int durationMinutes,
      String instructions = ''}) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/instant-bookings',
        {
          'addressId': addressId,
          'durationMinutes': durationMinutes,
          'instructions': instructions,
        },
        token: token) as Map);
    return CustomerBooking.fromJson(payload);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/features/booking/data/booking_repository.dart';

void main() {
  CustomerBooking booking(String status) => CustomerBooking(
        id: 35,
        service: 'Basic Home Cleaning',
        services: const ['Basic Home Cleaning'],
        address: 'Test address',
        pinCode: '712250',
        scheduledFor: '2026-08-16T18:32:00',
        durationMinutes: 60,
        optionLabel: 'Instant Maid',
        promoCode: '',
        discountPaise: 0,
        specialInstructions: '',
        status: status,
        customer: 'Customer',
        worker: 'bot1212',
        rating: 0,
      );

  test('hides worker identity until the worker accepts', () {
    expect(booking('ASSIGNED').customerWorkerLabel,
        'Pending worker acceptance');
    expect(booking('ACCEPTED').customerWorkerLabel, 'bot1212');
  });

  test('uses customer-facing wording for assigned offers', () {
    expect(customerBookingStatusLabel('ASSIGNED'), 'AWAITING ACCEPTANCE');
    expect(customerBookingStatusLabel('ON_THE_WAY'), 'ON THE WAY');
  });
}

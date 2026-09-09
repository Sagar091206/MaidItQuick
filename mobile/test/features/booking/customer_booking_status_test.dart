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
    expect(customerBookingStatusLabel('SEARCHING'), 'FINDING PARTNER');
    expect(customerBookingStatusLabel('ASSIGNED'), 'AWAITING ACCEPTANCE');
    expect(customerBookingStatusLabel('ON_THE_WAY'), 'ON THE WAY');
  });

  test('canCancel returns true for all active lifecycle stages and false for terminal stages', () {
    expect(booking('SEARCHING').canCancel, isTrue);
    expect(booking('SEARCHING').isActive, isTrue);
    expect(booking('REQUESTED').canCancel, isTrue);
    expect(booking('ASSIGNED').canCancel, isTrue);
    expect(booking('ACCEPTED').canCancel, isTrue);
    expect(booking('ON_THE_WAY').canCancel, isTrue);
    expect(booking('ARRIVED').canCancel, isTrue);
    expect(booking('IN_PROGRESS').canCancel, isTrue);

    expect(booking('COMPLETED').canCancel, isFalse);
    expect(booking('CANCELLED').canCancel, isFalse);
    expect(booking('EXPIRED').canCancel, isFalse);
  });

  test('CustomerBooking.fromJson parses cancellation metadata properly', () {
    final b = CustomerBooking.fromJson({
      'id': 99,
      'status': 'CANCELLED',
      'cancellationReason': 'Partner requested to cancel',
      'cancellationStage': 'BEFORE_ARRIVAL',
      'cancelledBy': 'CUSTOMER',
      'cancelledAt': '2026-09-09T01:00:00Z',
      'cancellationDetails': 'Partner called and asked to cancel',
    });
    expect(b.cancellationReason, 'Partner requested to cancel');
    expect(b.cancellationStage, 'BEFORE_ARRIVAL');
    expect(b.cancelledBy, 'CUSTOMER');
    expect(b.cancellationDetails, 'Partner called and asked to cancel');
  });
}

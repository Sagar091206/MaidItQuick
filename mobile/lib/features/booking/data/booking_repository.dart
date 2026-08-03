import '../../../core/api_client.dart';

class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  Future<CustomerBooking> create(
    String token, {
    required List<String> services,
    String? service,
    required String address,
    required String pinCode,
    required String scheduledFor,
    int? durationMinutes,
    String optionLabel = 'Standard service',
    String promoCode = '',
    String specialInstructions = '',
  }) async {
    final payload = Map<String, dynamic>.from(await _api.post(
      '/bookings',
      {
        'service': service ?? services.join(', '),
        'services': services,
        'address': address,
        'pinCode': pinCode,
        'scheduledFor': scheduledFor,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'optionLabel': optionLabel,
        'promoCode': promoCode,
        'specialInstructions': specialInstructions,
      },
      token: token,
    ) as Map);
    return CustomerBooking.fromJson(payload);
  }

  Future<List<CustomerBooking>> list(String token) async {
    final payload = await _api.get('/bookings', token: token) as List;
    return payload
        .map((item) => CustomerBooking.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<CustomerBooking> fetch(String token, int id) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/bookings/$id', token: token) as Map);
    return CustomerBooking.fromJson(payload);
  }

  Future<CustomerBooking> cancel(String token, int id, String reason) async {
    final payload = Map<String, dynamic>.from(
        await _api.post('/bookings/$id/cancel', {'reason': reason}, token: token)
            as Map);
    return CustomerBooking.fromJson(payload);
  }

  Future<CustomerBooking> reschedule(String token, int id, String scheduledFor) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/bookings/$id/reschedule',
        {'scheduledFor': scheduledFor},
        token: token) as Map);
    return CustomerBooking.fromJson(payload);
  }

  Future<CustomerBooking> rate(String token, int id, int stars, String comment) async {
    final payload = Map<String, dynamic>.from(await _api.post(
      '/bookings/$id/rating',
      {'stars': stars, if (comment.isNotEmpty) 'comment': comment},
      token: token,
    ) as Map);
    return CustomerBooking.fromJson(payload);
  }

  /// Creates a payment intent for the booking with the chosen method.
  Future<PayIntent> createPayIntent(String token, int id, String method) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/bookings/$id/pay-intent', {'method': method}, token: token) as Map);
    return PayIntent.fromJson(payload);
  }

  /// Executes the mock-gateway payment against the intent.
  Future<PaymentRecord> pay(
    String token, {
    required int bookingId,
    required int intentId,
    required String method,
    String upiId = '',
    String cardLast4 = '',
    String bankName = '',
  }) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/bookings/$bookingId/pay',
        {
          'intentId': '$intentId',
          'method': method,
          if (upiId.isNotEmpty) 'upiId': upiId,
          if (cardLast4.isNotEmpty) 'cardLast4': cardLast4,
          if (bankName.isNotEmpty) 'bankName': bankName,
        },
        token: token) as Map);
    return PaymentRecord.fromJson(
        Map<String, dynamic>.from(payload['payment'] as Map));
  }

  /// Latest payment record for the booking (or an UNPAID placeholder).
  Future<PaymentRecord> fetchPayment(String token, int bookingId) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/bookings/$bookingId/payment', token: token) as Map);
    return PaymentRecord.fromJson(payload);
  }
}

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.service,
    required this.services,
    required this.address,
    required this.pinCode,
    required this.scheduledFor,
    required this.durationMinutes,
    required this.optionLabel,
    required this.promoCode,
    required this.discountPaise,
    required this.specialInstructions,
    required this.status,
    required this.customer,
    required this.worker,
    required this.rating,
    this.paymentStatus = 'UNPAID',
    this.paymentAmountPaise = 0,
    this.paymentMethod = '',
    this.paidAt,
    this.startOtpIssued = false,
    this.endOtpIssued = false,
    this.cancellationReason = '',
    this.events = const [],
  });

  factory CustomerBooking.fromJson(Map<String, dynamic> json) => CustomerBooking(
        id: (json['id'] as num).toInt(),
        service: json['service'] as String? ?? '',
        services: (json['services'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
        address: json['address'] as String? ?? '',
        pinCode: json['pinCode'] as String? ?? '',
        scheduledFor: json['scheduledFor'] as String? ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        optionLabel: json['optionLabel'] as String? ?? '',
        promoCode: json['promoCode'] as String? ?? '',
        discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
        specialInstructions: json['specialInstructions'] as String? ?? '',
        status: json['status'] as String? ?? '',
        paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
        paymentAmountPaise:
            (json['paymentAmountPaise'] as num?)?.toInt() ?? 0,
        paymentMethod: json['paymentMethod'] as String? ?? '',
        paidAt: json['paidAt'] as String?,
        startOtpIssued: json['startOtpIssued'] as bool? ?? false,
        endOtpIssued: json['endOtpIssued'] as bool? ?? false,
        customer: json['customer'] as String? ?? '',
        worker: json['worker'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        cancellationReason: json['cancellationReason'] as String? ?? '',
        events: (json['events'] as List?)
                ?.map((item) =>
                    BookingEvent.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList() ??
            const [],
      );

  final int id;
  final String service;
  final List<String> services;
  final String address;
  final String pinCode;
  final String scheduledFor;
  final int durationMinutes;
  final String optionLabel;
  final String promoCode;
  final int discountPaise;
  final String specialInstructions;
  final String status;
  final String paymentStatus;
  final int paymentAmountPaise;
  final String paymentMethod;
  final String? paidAt;
  final bool startOtpIssued;
  final bool endOtpIssued;
  final String customer;
  final String worker;
  final int rating;
  final String cancellationReason;
  final List<BookingEvent> events;

  bool get isActive =>
      status == 'REQUESTED' ||
      status == 'ASSIGNED' ||
      status == 'ACCEPTED' ||
      status == 'ON_THE_WAY' ||
      status == 'ARRIVED' ||
      status == 'IN_PROGRESS';

  bool get isPaid => paymentStatus == 'PAID';

  /// Active booking whose payment is still pending and can be completed.
  bool get needsPayment => !isPaid && isActive;

  bool get canCancel => status == 'REQUESTED' || status == 'ASSIGNED';

  bool get canReschedule => status == 'REQUESTED';

  bool get canRate => status == 'COMPLETED' && rating == 0;

  bool get isCompleted => status == 'COMPLETED';
}

/// Payment intent created for a booking before executing the payment.
class PayIntent {
  const PayIntent({
    required this.intentId,
    required this.bookingId,
    required this.reference,
    required this.amountPaise,
    required this.method,
    required this.status,
  });

  factory PayIntent.fromJson(Map<String, dynamic> json) => PayIntent(
        intentId: (json['intentId'] as num).toInt(),
        bookingId: (json['bookingId'] as num).toInt(),
        reference: json['reference'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        method: json['method'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );

  final int intentId;
  final int bookingId;
  final String reference;
  final int amountPaise;
  final String method;
  final String status;
}

/// One payment ledger record (intent outcome from the gateway).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.reference,
    required this.method,
    required this.amountPaise,
    required this.status,
    required this.gatewayResponse,
    this.completedAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        reference: json['reference'] as String? ?? '',
        method: json['method'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        gatewayResponse: json['gatewayResponse'] as String? ?? '',
        completedAt: json['completedAt'] as String?,
      );

  final int id;
  final String reference;
  final String method;
  final int amountPaise;
  final String status;
  final String gatewayResponse;
  final String? completedAt;

  bool get isPaid => status == 'PAID';
}

class BookingEvent {
  const BookingEvent({
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory BookingEvent.fromJson(Map<String, dynamic> json) => BookingEvent(
        status: json['status'] as String? ?? '',
        note: json['note'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  final String status;
  final String note;
  final String createdAt;
}

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

  bool get canCancel => status == 'REQUESTED' || status == 'ASSIGNED';

  bool get canReschedule => status == 'REQUESTED';

  bool get canRate => status == 'COMPLETED' && rating == 0;

  bool get isCompleted => status == 'COMPLETED';
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

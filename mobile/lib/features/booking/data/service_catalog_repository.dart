import '../../../core/api_client.dart';

/// Public catalog, availability and booking-planning endpoints used by the
/// customer booking flow. None of these calls require a session token.
class ServiceCatalogRepository {
  ServiceCatalogRepository(this._api);

  final ApiClient _api;

  Future<List<CatalogService>> listServices({String query = '', String? pinCode}) async {
    final parameters = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (pinCode != null && pinCode.trim().isNotEmpty) 'pinCode': pinCode.trim(),
    };
    final path = Uri(path: '/services', queryParameters: parameters.isEmpty ? null : parameters).toString();
    final payload = await _api.get(path) as List;
    return payload
        .map((item) =>
            CatalogService.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Fetches a single enabled service with its full details.
  Future<CatalogService> fetchDetail(int id, {String? pinCode}) async {
    final suffix = pinCode == null || pinCode.trim().isEmpty
        ? ''
        : '?pinCode=${Uri.encodeQueryComponent(pinCode.trim())}';
    final payload = Map<String, dynamic>.from(
        await _api.get('/services/$id$suffix') as Map);
    return CatalogService.fromJson(payload);
  }

  Future<AvailabilityStatus> checkAvailability(String pinCode) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/availability?pinCode=$pinCode') as Map);
    return AvailabilityStatus.fromJson(payload);
  }

  /// Returns the estimated duration in minutes for the selected services.
  /// Sends the session token because `/api/booking/**` requires authentication.
  Future<int> calculateDuration(List<String> services, {String? token}) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/booking/calculate-duration',
        {'services': services},
        token: token) as Map);
    return (payload['durationMinutes'] as num).toInt();
  }

  /// Fetches the availability of the standard time slots for a PIN and date.
  /// Sends the session token because `/api/booking/**` requires authentication.
  Future<List<Map<String, dynamic>>> fetchSlots(
      String pinCode, String date,
      {String? token}) async {
    final payload = await _api.get('/booking/slots?pinCode=$pinCode&date=$date',
        token: token) as List;
    return List<Map<String, dynamic>>.from(payload);
  }

  /// Server-authoritative itemised quote for the selected services.
  Future<BookingQuote> fetchQuote(
    String token, {
    required List<String> services,
    required int durationMinutes,
    required String pinCode,
    String promoCode = '',
  }) async {
    final query = StringBuffer('/booking/quote?durationMinutes=$durationMinutes');
    query.write('&pinCode=${Uri.encodeQueryComponent(pinCode.trim())}');
    for (final service in services) {
      query.write('&services=${Uri.encodeQueryComponent(service)}');
    }
    if (promoCode.trim().isNotEmpty) {
      query.write('&promoCode=${Uri.encodeQueryComponent(promoCode.trim())}');
    }
    final payload = Map<String, dynamic>.from(
        await _api.get(query.toString(), token: token) as Map);
    return BookingQuote.fromJson(payload);
  }
}

class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.enabled,
    this.description = '',
    this.emoji = '',
    this.defaultDurationMinutes = 60,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        pricePaise: (json['pricePaise'] as num).toInt(),
        enabled: json['enabled'] as bool? ?? true,
        description: json['description'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        defaultDurationMinutes:
            (json['defaultDurationMinutes'] as num?)?.toInt() ?? 60,
      );

  final int id;
  final String name;
  final int pricePaise;
  final bool enabled;
  final String description;
  final String emoji;
  final int defaultDurationMinutes;

  String get priceLabel => 'From Rs ${(pricePaise / 100).round()}';
}

class AvailabilityStatus {
  const AvailabilityStatus({
    required this.status,
    required this.label,
    required this.message,
    this.etaMinutes,
  });

  factory AvailabilityStatus.fromJson(Map<String, dynamic> json) =>
      AvailabilityStatus(
        status: json['status'] as String? ?? '',
        label: json['label'] as String? ?? '',
        message: json['message'] as String? ?? '',
        etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      );

  final String status;
  final String label;
  final String message;
  final int? etaMinutes;

  bool get available =>
      status == 'AVAILABLE_NOW' || status == 'AVAILABLE_LATER';
}

/// Server-authoritative itemised quote for the booking summary.
class BookingQuote {
  const BookingQuote({
    required this.currency,
    required this.lines,
    required this.subtotalPaise,
    required this.promoCode,
    required this.discountPaise,
    required this.totalPaise,
    this.taxPaise = 0,
    this.convenienceFeePaise = 0,
  });

  factory BookingQuote.fromJson(Map<String, dynamic> json) => BookingQuote(
        currency: json['currency'] as String? ?? 'INR',
        lines: (json['lines'] as List? ?? const [])
            .map((item) =>
                QuoteLine.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        subtotalPaise: (json['subtotalPaise'] as num?)?.toInt() ?? 0,
        promoCode: json['promoCode'] as String? ?? '',
        discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
        taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
        convenienceFeePaise:
            (json['convenienceFeePaise'] as num?)?.toInt() ?? 0,
        totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
      );

  final String currency;
  final List<QuoteLine> lines;
  final int subtotalPaise;
  final String promoCode;
  final int discountPaise;
  final int taxPaise;
  final int convenienceFeePaise;
  final int totalPaise;
}

class QuoteLine {
  const QuoteLine({
    required this.name,
    required this.pricePaise,
    required this.amountPaise,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        name: json['name'] as String? ?? '',
        pricePaise: (json['pricePaise'] as num?)?.toInt() ?? 0,
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final int pricePaise;
  final int amountPaise;
}

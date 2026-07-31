import '../../../core/api_client.dart';

/// Public catalog, availability and booking-planning endpoints used by the
/// customer booking flow. None of these calls require a session token.
class ServiceCatalogRepository {
  ServiceCatalogRepository(this._api);

  final ApiClient _api;

  Future<List<CatalogService>> listServices({String query = ''}) async {
    final path = query.trim().isEmpty
        ? '/services'
        : '/services?q=${Uri.encodeQueryComponent(query.trim())}';
    final payload = await _api.get(path) as List;
    return payload
        .map((item) =>
            CatalogService.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AvailabilityStatus> checkAvailability(String pinCode) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/availability?pinCode=$pinCode') as Map);
    return AvailabilityStatus.fromJson(payload);
  }

  /// Returns the estimated duration in minutes for the selected services.
  Future<int> calculateDuration(List<String> services) async {
    final payload = Map<String, dynamic>.from(await _api.post(
        '/booking/calculate-duration',
        {'services': services}) as Map);
    return (payload['durationMinutes'] as num).toInt();
  }
}

class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.enabled,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        pricePaise: (json['pricePaise'] as num).toInt(),
        enabled: json['enabled'] as bool? ?? true,
      );

  final int id;
  final String name;
  final int pricePaise;
  final bool enabled;

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

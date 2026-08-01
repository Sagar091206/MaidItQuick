import '../../../core/api_client.dart';

class CustomerDashboardRepository {
  CustomerDashboardRepository(this._api);

  final ApiClient _api;

  Future<CustomerDashboard> fetch(String token) async {
    final payload =
        Map<String, dynamic>.from(await _api.get('/customer/dashboard', token: token) as Map);
    return CustomerDashboard.fromJson(payload);
  }

  Future<List<ServiceCategory>> searchServices(String query) async {
    final path = query.trim().isEmpty
        ? '/services'
        : '/services?q=${Uri.encodeQueryComponent(query.trim())}';
    final payload = await _api.get(path);
    return List<Map<String, dynamic>>.from(payload as List)
        .map(ServiceCategory.fromJson)
        .toList();
  }
}

class CustomerDashboard {
  const CustomerDashboard({
    required this.welcomeName,
    required this.addresses,
    required this.services,
    this.activeBooking,
    this.recentBooking,
  });

  factory CustomerDashboard.fromJson(Map<String, dynamic> json) => CustomerDashboard(
        welcomeName: json['welcomeName'] as String? ?? '',
        addresses: List<Map<String, dynamic>>.from(json['addresses'] as List? ?? const []),
        services: List<Map<String, dynamic>>.from(json['services'] as List? ?? const [])
            .map(ServiceCategory.fromJson)
            .toList(),
        activeBooking: json['activeBooking'] == null
            ? null
            : DashboardBooking.fromJson(
                Map<String, dynamic>.from(json['activeBooking'] as Map)),
        recentBooking: json['recentBooking'] == null
            ? null
            : DashboardBooking.fromJson(
                Map<String, dynamic>.from(json['recentBooking'] as Map)),
      );

  final String welcomeName;
  final List<Map<String, dynamic>> addresses;
  final List<ServiceCategory> services;
  final DashboardBooking? activeBooking;
  final DashboardBooking? recentBooking;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.pricePaise,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        pricePaise: (json['pricePaise'] as num).toInt(),
      );

  final int id;
  final String name;
  final int pricePaise;

  String get priceLabel => 'From Rs ${(pricePaise / 100).round()}';
}

class DashboardBooking {
  const DashboardBooking({
    required this.id,
    required this.service,
    required this.address,
    required this.scheduledFor,
    required this.status,
    required this.durationMinutes,
    required this.worker,
  });

  factory DashboardBooking.fromJson(Map<String, dynamic> json) => DashboardBooking(
        id: (json['id'] as num).toInt(),
        service: json['service'] as String? ?? '',
        address: json['address'] as String? ?? '',
        scheduledFor: json['scheduledFor'] as String? ?? '',
        status: json['status'] as String? ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        worker: json['worker'] as String? ?? 'Unassigned',
      );

  final int id;
  final String service;
  final String address;
  final String scheduledFor;
  final String status;
  final int durationMinutes;
  final String worker;
}

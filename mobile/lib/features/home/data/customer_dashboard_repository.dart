import '../../../core/api_client.dart';

class CustomerDashboardRepository {
  CustomerDashboardRepository(this._api);

  final ApiClient _api;

  Future<CustomerDashboard> fetch(String token) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/customer/dashboard', token: token) as Map);
    return CustomerDashboard.fromJson(payload);
  }

  Future<List<ServiceCategory>> searchServices(String query, {String? pinCode}) async {
    final parameters = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (pinCode != null && pinCode.trim().isNotEmpty) 'pinCode': pinCode.trim(),
    };
    final path = Uri(path: '/services', queryParameters: parameters.isEmpty ? null : parameters).toString();
    final payload = await _api.get(path);
    return List<Map<String, dynamic>>.from(payload as List)
        .map(ServiceCategory.fromJson)
        .toList();
  }

  /// Marks an address as the customer's default and returns the updated one.
  Future<DashboardAddress> setDefaultAddress(String token, int id) async {
    final payload = Map<String, dynamic>.from(await _api.put(
        '/customer/addresses/$id/default', {}, token: token) as Map);
    return DashboardAddress.fromJson(payload);
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

  factory CustomerDashboard.fromJson(Map<String, dynamic> json) =>
      CustomerDashboard(
        welcomeName: json['welcomeName'] as String? ?? '',
        addresses:
            List<Map<String, dynamic>>.from(json['addresses'] as List? ?? const [])
                .map(DashboardAddress.fromJson)
                .toList(),
        services: List<Map<String, dynamic>>.from(
                json['services'] as List? ?? const [])
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
  final List<DashboardAddress> addresses;
  final List<ServiceCategory> services;
  final DashboardBooking? activeBooking;
  final DashboardBooking? recentBooking;

  DashboardAddress? get defaultAddress {
    for (final address in addresses) {
      if (address.defaultAddress) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }
}

/// A saved address as surfaced by the dashboard payload.
class DashboardAddress {
  const DashboardAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.pinCode,
    required this.defaultAddress,
  });

  factory DashboardAddress.fromJson(Map<String, dynamic> json) =>
      DashboardAddress(
        id: (json['id'] as num).toInt(),
        label: json['label'] as String? ?? '',
        address: json['address'] as String? ?? '',
        pinCode: json['pinCode'] as String? ?? '',
        defaultAddress: json['defaultAddress'] as bool? ?? false,
      );

  final int id;
  final String label;
  final String address;
  final String pinCode;
  final bool defaultAddress;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.pricePaise,
    this.emoji = '',
    this.description = '',
    this.defaultDurationMinutes = 60,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        pricePaise: (json['pricePaise'] as num).toInt(),
        emoji: json['emoji'] as String? ?? '',
        description: json['description'] as String? ?? '',
        defaultDurationMinutes:
            (json['defaultDurationMinutes'] as num?)?.toInt() ?? 60,
      );

  final int id;
  final String name;
  final int pricePaise;
  final String emoji;
  final String description;
  final int defaultDurationMinutes;

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

  factory DashboardBooking.fromJson(Map<String, dynamic> json) =>
      DashboardBooking(
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

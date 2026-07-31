import '../../../core/api_client.dart';

/// CRUD for the signed-in customer's saved service addresses.
///
/// Every call sends the session token so the backend resolves the address
/// against the customer account from the JWT.
class CustomerAddressesRepository {
  CustomerAddressesRepository(this._api);

  final ApiClient _api;

  Future<List<CustomerAddress>> list(String token) async {
    final payload = await _api.get('/customer/addresses', token: token) as List;
    return payload
        .map((item) =>
            CustomerAddress.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<CustomerAddress> create(String token, CustomerAddressDraft draft) async {
    final payload = Map<String, dynamic>.from(
        await _api.post('/customer/addresses', draft.toJson(), token: token)
            as Map);
    return CustomerAddress.fromJson(payload);
  }

  Future<CustomerAddress> update(
      String token, int id, CustomerAddressDraft draft) async {
    final payload = Map<String, dynamic>.from(
        await _api.put('/customer/addresses/$id', draft.toJson(), token: token)
            as Map);
    return CustomerAddress.fromJson(payload);
  }

  Future<CustomerAddress> setDefault(String token, int id) async {
    final payload = Map<String, dynamic>.from(await _api.put(
        '/customer/addresses/$id/default',
        {},
        token: token) as Map);
    return CustomerAddress.fromJson(payload);
  }

  Future<void> delete(String token, int id) async {
    await _api.delete('/customer/addresses/$id', token: token);
  }
}

/// A saved address as returned by the backend.
class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.pinCode,
    required this.houseNumber,
    required this.building,
    required this.street,
    required this.area,
    required this.landmark,
    required this.city,
    required this.state,
    required this.defaultAddress,
    this.latitude,
    this.longitude,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) =>
      CustomerAddress(
        id: (json['id'] as num).toInt(),
        label: json['label'] as String? ?? '',
        address: json['address'] as String? ?? '',
        pinCode: json['pinCode'] as String? ?? '',
        houseNumber: json['houseNumber'] as String? ?? '',
        building: json['building'] as String? ?? '',
        street: json['street'] as String? ?? '',
        area: json['area'] as String? ?? '',
        landmark: json['landmark'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        defaultAddress: json['defaultAddress'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  final int id;
  final String label;
  final String address;
  final String pinCode;
  final String houseNumber;
  final String building;
  final String street;
  final String area;
  final String landmark;
  final String city;
  final String state;
  final bool defaultAddress;
  final double? latitude;
  final double? longitude;

  /// Plain JSON view used by screens that keep lightweight map state.
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'address': address,
        'pinCode': pinCode,
        'houseNumber': houseNumber,
        'building': building,
        'street': street,
        'area': area,
        'landmark': landmark,
        'city': city,
        'state': state,
        'defaultAddress': defaultAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Payload for creating or updating a saved address.
class CustomerAddressDraft {
  const CustomerAddressDraft({
    required this.label,
    required this.houseNumber,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.pinCode,
    this.building = '',
    this.landmark = '',
    this.defaultAddress = false,
    this.latitude,
    this.longitude,
  });

  final String label;
  final String houseNumber;
  final String building;
  final String street;
  final String area;
  final String landmark;
  final String city;
  final String state;
  final String pinCode;
  final bool defaultAddress;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
        'label': label,
        'houseNumber': houseNumber,
        'building': building,
        'street': street,
        'area': area,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pinCode': pinCode,
        'defaultAddress': defaultAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

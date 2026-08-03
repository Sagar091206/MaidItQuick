import '../../../core/api_client.dart';

class CustomerProfileRepository {
  CustomerProfileRepository(this._api);

  final ApiClient _api;

  Future<CustomerProfile> fetch(String token) async {
    final payload =
        Map<String, dynamic>.from(await _api.get('/customer/profile', token: token) as Map);
    return CustomerProfile.fromJson(payload);
  }

  Future<CustomerProfile> save({
    required String token,
    required String name,
    String? email,
    String? gender,
    String? dob,
    String? profileImage,
  }) async {
    final payload = Map<String, dynamic>.from(await _api.put(
      '/customer/profile',
      {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (profileImage != null && profileImage.isNotEmpty)
          'profileImage': profileImage,
      },
      token: token,
    ) as Map);
    return CustomerProfile.fromJson(payload);
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.gender,
    required this.dob,
    required this.profileImage,
    required this.profileComplete,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) => CustomerProfile(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        dob: json['dob'] as String? ?? '',
        profileImage: json['profileImage'] as String? ?? '',
        profileComplete: json['profileComplete'] as bool? ?? false,
      );

  final String name;
  final String phone;
  final String email;
  final String gender;
  final String dob;
  final String profileImage;
  final bool profileComplete;
}

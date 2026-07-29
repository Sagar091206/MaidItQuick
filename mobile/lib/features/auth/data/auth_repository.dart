import '../../../core/api_client.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role.apiValue,
    });
  }

  Future<Session> login({required String email, required String password}) async {
    final payload = await _api.post('/auth/login', {'email': email, 'password': password});
    return Session(token: payload['token'] as String, role: payload['role'] as String, name: payload['name'] as String);
  }

  Future<OtpChallenge> startPartnerSignup({required String name, required String phone}) async {
    final payload = await _api.post('/auth/partner/otp/signup/start', {
      'name': name,
      'phone': phone,
    });
    return OtpChallenge.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<OtpChallenge> startPartnerLogin({required String phone}) async {
    final payload = await _api.post('/auth/partner/otp/login/start', {'phone': phone});
    return OtpChallenge.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<Session> verifyPartnerOtp({required String phone, required String purpose, required String otp}) async {
    final payload = await _api.post('/auth/partner/otp/verify', {
      'phone': phone,
      'purpose': purpose,
      'otp': otp,
    });
    return Session(token: payload['token'] as String, role: payload['role'] as String, name: payload['name'] as String);
  }
}

class OtpChallenge {
  const OtpChallenge({required this.phone, required this.expiresInSeconds, this.devOtp});

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        phone: json['phone'] as String,
        expiresInSeconds: json['expiresInSeconds'] as int,
        devOtp: json['devOtp'] as String?,
      );

  final String phone;
  final int expiresInSeconds;
  final String? devOtp;
}

enum UserRole {
  customer('customer', 'Customer'),
  partner('worker', 'Partner');

  const UserRole(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class Session {
  const Session({required this.token, required this.role, required this.name});
  final String token;
  final String role;
  final String name;
}

import '../../../core/api_client.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<OtpChallenge> sendOtp({required String phone}) async {
    final payload = await _api.post('/v1/auth/send-otp', {'phone': phone});
    return OtpChallenge.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<AuthV1Result> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final payload =
        await _api.post('/v1/auth/verify-otp', {'phone': phone, 'otp': otp});
    return AuthV1Result.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<Session> completeProfile({
    required String pendingToken,
    required String name,
    String? email,
    String? gender,
    String? dob,
    String? profileImage,
  }) async {
    final payload = await _api.post('/v1/auth/complete-profile', {
      'pendingToken': pendingToken,
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (dob != null && dob.isNotEmpty) 'dob': dob,
      if (profileImage != null && profileImage.isNotEmpty)
        'profileImage': profileImage,
    });
    return Session.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<Session> validateSession(String token) async {
    final payload = await _api.get('/auth/session', token: token);
    return Session.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<void> logout(String token) async {
    await _api.post('/auth/logout', {}, token: token);
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

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        role: json['role'] as String,
        name: json['name'] as String? ?? '',
      );

  final String token;
  final String role;
  final String name;
}

/// Result of verifying an OTP for the unified customer flow.
///
/// An existing customer receives a [session]; a new customer receives a
/// [pendingToken] that must be exchanged via the complete-profile call.
class AuthV1Result {
  const AuthV1Result({required this.existing, this.session, this.pendingToken, required this.phone});

  factory AuthV1Result.fromJson(Map<String, dynamic> json) {
    final existing = json['existing'] as bool? ?? false;
    return AuthV1Result(
      existing: existing,
      session: existing
          ? Session(
              token: json['token'] as String,
              role: json['role'] as String? ?? 'customer',
              name: json['name'] as String? ?? '',
            )
          : null,
      pendingToken: existing ? null : json['pendingToken'] as String?,
      phone: json['phone'] as String? ?? '',
    );
  }

  final bool existing;
  final Session? session;
  final String? pendingToken;
  final String phone;
}

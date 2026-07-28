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
}

enum UserRole {
  customer('customer', 'Customer'),
  partner('worker', 'Maid Partner');

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

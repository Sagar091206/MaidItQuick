import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

/// Persists the session with the token in the platform keystore/keychain
/// (flutter_secure_storage) and the non-sensitive role/name in
/// SharedPreferences.
///
/// Every secure-storage call degrades gracefully: if the platform store is
/// unavailable (for example in widget tests) the session behaves as if absent
/// and no exception escapes to callers.
class SessionStore {
  static const _tokenKey = 'miq.session.token';
  static const _legacyTokenKey = 'miq.session.token';
  static const _roleKey = 'miq.session.role';
  static const _nameKey = 'miq.session.name';

  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<Session?> load() async {
    String? token;
    try {
      token = await _secure.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        // Migrate a token saved by older builds into the secure store.
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(_legacyTokenKey);
        if (legacy != null && legacy.isNotEmpty) {
          token = legacy;
          await _secure.write(key: _tokenKey, value: legacy);
          await prefs.remove(_legacyTokenKey);
        }
      }
    } catch (_) {
      return null;
    }
    if (token == null || token.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return Session(
      token: token,
      role: canonicalRole(prefs.getString(_roleKey)),
      name: prefs.getString(_nameKey) ?? '',
    );
  }

  Future<void> save(Session session) async {
    try {
      await _secure.write(key: _tokenKey, value: session.token);
    } catch (_) {
      // The session cannot be restored later, but signing in still works.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, canonicalRole(session.role));
    await prefs.setString(_nameKey, session.name);
  }

  Future<void> clear() async {
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {
      // Nothing left to clear.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
  }
}

import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/brand_theme.dart';
import 'core/theme_prefs.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/session_store.dart';
import 'features/profile/presentation/customer_shell.dart';
import 'features/onboarding/presentation/journey_screens.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() => runApp(const MaidItQuickApp());

class MaidItQuickApp extends StatefulWidget {
  const MaidItQuickApp({super.key});

  @override
  State<MaidItQuickApp> createState() => _MaidItQuickAppState();
}

class _MaidItQuickAppState extends State<MaidItQuickApp> {
  static const _splashDuration = Duration(milliseconds: 2200);

  final ApiClient _api = ApiClient();
  final SessionStore _sessionStore = SessionStore();
  final ThemePrefs _themePrefs = ThemePrefs();
  Session? _session;
  UserRole? _chosenRole;
  bool _splashVisible = true;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _restoreSession(),
      _restoreTheme(),
      Future<void>.delayed(_splashDuration),
    ]);
    if (mounted) setState(() => _splashVisible = false);
  }

  Future<void> _restoreSession() async {
    final stored = await _sessionStore.load();
    if (stored != null) {
      try {
        final validated = await AuthRepository(_api).validateSession(stored.token);
        if (mounted) {
          setState(() => _session = validated);
          await _sessionStore.save(validated);
        }
      } catch (_) {
        await _sessionStore.clear();
      }
    }
  }

  Future<void> _restoreTheme() async {
    final mode = await _themePrefs.load();
    if (mounted) setState(() => _themeMode = mode);
  }

  void _chooseRole(UserRole role) => setState(() => _chosenRole = role);

  void _backToWelcome() => setState(() => _chosenRole = null);

  Future<void> _authenticated(Session session) async {
    await _sessionStore.save(session);
    if (mounted) {
      setState(() {
        _session = session;
        _chosenRole = null;
      });
    }
  }

  Future<void> _sessionUpdated(Session session) async {
    await _sessionStore.save(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _logout() async {
    final token = _session?.token;
    if (token != null) {
      try {
        await AuthRepository(_api).logout(token);
      } catch (_) {
        // Local session is cleared even when the API is unreachable.
      }
    }
    await _sessionStore.clear();
    if (mounted) setState(() => _session = null);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await _themePrefs.save(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaidItQuick',
      debugShowCheckedModeBanner: false,
      theme: maidItQuickLightTheme(),
      darkTheme: maidItQuickDarkTheme(),
      themeMode: _themeMode,
      home: _home(),
    );
  }

  Widget _home() {
    if (_splashVisible) {
      return const SplashScreen();
    }
    final session = _session;
    if (session != null) {
      return session.role.toUpperCase() == 'WORKER'
          ? PartnerJourneyScreen(api: _api, session: session, onLogout: _logout)
          : CustomerShell(
              api: _api,
              session: session,
              onLogout: _logout,
              onSessionUpdated: _sessionUpdated,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode);
    }
    if (_chosenRole != null) {
      return AuthScreen(
        api: _api,
        role: _chosenRole!,
        onBack: _backToWelcome,
        onAuthenticated: _authenticated,
      );
    }
    return WelcomeScreen(onChooseRole: _chooseRole);
  }
}

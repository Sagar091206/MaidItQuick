import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/brand_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/onboarding/presentation/journey_screens.dart';

void main() => runApp(const MaidItQuickApp());

class MaidItQuickApp extends StatefulWidget {
  const MaidItQuickApp({super.key});

  @override
  State<MaidItQuickApp> createState() => _MaidItQuickAppState();
}

class _MaidItQuickAppState extends State<MaidItQuickApp> {
  final ApiClient _api = ApiClient();
  Session? _session;
  UserRole? _chosenRole;

  void _chooseRole(UserRole role) => setState(() => _chosenRole = role);

  void _backToWelcome() => setState(() => _chosenRole = null);

  void _authenticated(Session session) {
    setState(() {
      _session = session;
      _chosenRole = null;
    });
  }

  void _logout() => setState(() => _session = null);

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MaterialApp(
      title: 'MaidItQuick',
      debugShowCheckedModeBanner: false,
      theme: maidItQuickTheme(),
      home: session != null
          ? session.role == 'WORKER'
              ? PartnerJourneyScreen(
                  api: _api, session: session, onLogout: _logout)
              : CustomerJourneyScreen(
                  api: _api, session: session, onLogout: _logout)
          : _chosenRole != null
              ? AuthScreen(
                  api: _api,
                  role: _chosenRole!,
                  onBack: _backToWelcome,
                  onAuthenticated: _authenticated)
              : WelcomeScreen(onChooseRole: _chooseRole),
    );
  }
}

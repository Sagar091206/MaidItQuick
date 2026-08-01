import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance preference. The brand follows the device
/// appearance by default (light-first), while users can pin Light, Dark or
/// System from settings.
class ThemePrefs {
  static const _key = 'miq.theme.mode';

  static const _default = ThemeMode.system;

  Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => _default,
      };
    } catch (_) {
      return _default;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, switch (mode) { ThemeMode.light => 'light', ThemeMode.system => 'system', _ => 'dark' });
  }
}

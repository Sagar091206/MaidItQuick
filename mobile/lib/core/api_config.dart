import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return _localMachineBaseUrl;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8080/api',
      TargetPlatform.iOS || TargetPlatform.macOS => _localMachineBaseUrl,
      _ => _localMachineBaseUrl,
    };
  }

  static const _localMachineBaseUrl = 'http://127.0.0.1:8080/api';
}

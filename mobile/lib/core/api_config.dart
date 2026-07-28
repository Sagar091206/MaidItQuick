class ApiConfig {
  const ApiConfig._();

  // Android emulator: http://10.0.2.2:8080/api
  // Production: replace with the deployed HTTPS endpoint.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );
}

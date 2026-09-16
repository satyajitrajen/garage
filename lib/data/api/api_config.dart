/// Compile-time API configuration.
///
/// Pass `--dart-define=API_BASE_URL=https://api.example.com` for staging/prod.
/// Defaults to local dev server.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-production-bef9.up.railway.app',
  );

  static const Duration timeout = Duration(seconds: 15);

  /// `false` when talking to a real backend instead of the in-memory mock.
  /// Defaults to `false` to use the deployed production backend.
  /// Flip via `--dart-define=USE_MOCK=true` to test in offline mock mode.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}

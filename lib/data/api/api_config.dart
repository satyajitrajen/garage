/// Compile-time API configuration.
///
/// Pass `--dart-define=API_BASE_URL=https://api.example.com` to target any
/// backend (e.g. a local dev server). Without it, every build mode uses the
/// production backend.
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String productionUrl =
      'https://garage.nexorytechnologies.com';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return productionUrl;
  }

  static const Duration timeout = Duration(seconds: 15);

  /// `true` runs the app on in-memory mock data with no backend.
  /// Flip via `--dart-define=USE_MOCK=true`.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}

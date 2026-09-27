import 'package:flutter/foundation.dart';

/// Compile-time API configuration.
///
/// Pass `--dart-define=API_BASE_URL=https://api.example.com` to target any
/// backend. Without it, release builds use the production backend and
/// debug/profile builds use a local dev server, so day-to-day development
/// never writes test data into production.
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String productionUrl =
      'https://backend-production-bef9.up.railway.app';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return productionUrl;
    // The Android emulator reaches the host machine via 10.0.2.2.
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }

  static const Duration timeout = Duration(seconds: 15);

  /// `true` runs the app on in-memory mock data with no backend.
  /// Flip via `--dart-define=USE_MOCK=true`.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../firebase_options.dart';

/// Runs when a push arrives while the app is in the background or killed;
/// the OS shows the notification itself, so there is nothing else to do.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options != null) await Firebase.initializeApp(options: options);
}

/// Firebase Cloud Messaging for NT Garage. The backend pushes to the tokens
/// registered for a garage, so this keeps the device's token registered to
/// the garage the user is signed in to.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  String? _token;
  bool _initialized = false;

  // The garage the current token is registered to, and the client used, so
  // a token refresh or logout can reach the same garage.
  ApiClient? _client;
  String? _registeredGarage;

  /// Initializes Firebase and asks for notification permission. Safe to call
  /// on unsupported platforms (web/desktop), where it does nothing.
  Future<void> initialize() async {
    if (_initialized) return;
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _messaging!.requestPermission(alert: true, badge: true, sound: true);
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _token = await _messaging!.getToken();
      // A refreshed token must be re-registered, or this device silently
      // stops receiving its garage's pushes. Tokens are credentials: never
      // log them.
      _messaging!.onTokenRefresh.listen((token) {
        _token = token;
        final client = _client;
        final garage = _registeredGarage;
        if (client != null && garage != null) {
          _registeredGarage = null;
          unawaited(register(client, garage));
        }
      });
      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] init skipped: $e');
    }
  }

  /// Registers this device for [garageId]'s pushes; a no-op if it already is
  /// or push is unavailable. Best effort: failures never surface to the UI.
  Future<void> register(ApiClient client, String garageId) async {
    final token = _token;
    if (token == null || garageId.isEmpty || _registeredGarage == garageId) {
      return;
    }
    try {
      await client.post('/api/garages/$garageId/devices/token', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      _client = client;
      _registeredGarage = garageId;
    } catch (e) {
      debugPrint('[FCM] register failed: $e');
    }
  }

  /// Stops pushes to this device; call before the session is cleared.
  Future<void> unregister() async {
    final token = _token;
    final client = _client;
    final garage = _registeredGarage;
    _registeredGarage = null;
    if (token == null || client == null || garage == null) return;
    try {
      await client.delete('/api/garages/$garage/devices/token', {'token': token});
    } catch (e) {
      debugPrint('[FCM] unregister failed: $e');
    }
  }
}

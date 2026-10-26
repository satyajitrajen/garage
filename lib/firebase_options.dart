// Firebase client config for project nt-garage-68f68 (Firebase console >
// Project settings). These values are public identifiers, not secrets.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Options for the running platform, or null where push is not set up
  /// (web and desktop), so callers can skip Firebase there.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZlU6HqnU33vQDm046OY_eVnIxKfO7Bys',
    appId: '1:213449098711:android:5d012614f3d9c9c2857792',
    messagingSenderId: '213449098711',
    projectId: 'nt-garage-68f68',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAl0SXerUEiyTxuNMpDHoC01MdQPNp9y9s',
    appId: '1:213449098711:ios:ef252af1f9fba05e857792',
    messagingSenderId: '213449098711',
    projectId: 'nt-garage-68f68',
    iosBundleId: 'com.nexory.garage',
  );
}

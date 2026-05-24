import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _attempted = false;
  static bool _ready = false;

  static bool get isReady => _ready || Firebase.apps.isNotEmpty;

  static Future<bool> ensureInitialized() async {
    if (isReady) {
      _ready = true;
      return true;
    }

    if (_attempted) {
      return false;
    }

    _attempted = true;

    try {
      if (Firebase.apps.isEmpty) {
        // Explicitly define options from the google-services.json configuration
        const options = FirebaseOptions(
          apiKey: "AIzaSyAVh7q424DjGgcX4HqFfQujbYTO9NVyhx4",
          appId: kIsWeb
              ? "1:681383548257:web:aaa473976957e8900d2120" // typical mapping or web app ID
              : "1:681383548257:android:aaa473976957e8900d2120",
          messagingSenderId: "681383548257",
          projectId: "muhafiz-app-78b78",
          storageBucket: "muhafiz-app-78b78.firebasestorage.app",
        );
        
        await Firebase.initializeApp(options: options);
      }
      _ready = true;
      debugPrint('🔥 Firebase Initialized Successfully!');
    } catch (e, stack) {
      debugPrint('❌ Firebase initialization failed: $e');
      debugPrint('$stack');
      _ready = false;
    }

    return _ready;
  }
}

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for SweatMark
/// 
/// TO CONFIGURE:
/// 1. Go to https://console.firebase.google.com
/// 2. Create a new project called "SweatMark"
/// 3. Enable Authentication (Anonymous + Email/Password)
/// 4. Enable Firestore Database
/// 5. Click the Web icon (</>) to add a web app
/// 6. Copy the config values and replace the placeholders below
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ============================================
  // WEB CONFIGURATION
  // ============================================
  // Get these values from Firebase Console → Project Settings → Web App
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBE4LMUKyspTKEyr2i9ElgmeV5z8rA273c",
    authDomain: "sweatmark-v1.firebaseapp.com",
    projectId: "sweatmark-v1",
    storageBucket: "sweatmark-v1.firebasestorage.app",
    messagingSenderId: "529973334654",
    appId: "1:529973334654:web:8209432c028ac828c93e2f",
    measurementId: "G-M8QRPHL7ZE",
  );

  // ============================================
  // ANDROID CONFIGURATION (Optional - for later)
  // ============================================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBE4LMUKyspTKEyr2i9ElgmeV5z8rA273c',
    appId: '1:529973334654:android:8209432c028ac828c93e2f',
    messagingSenderId: '529973334654',
    projectId: 'sweatmark-v1',
    storageBucket: 'sweatmark-v1.firebasestorage.app',
  );

  // ============================================
  // iOS/macOS CONFIGURATION (Optional - for later)
  // ============================================
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.sweatmark',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.sweatmark',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );
}

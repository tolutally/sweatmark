# Manual Firebase Setup for SweatMark

Since the FlutterFire CLI is having issues, follow this manual setup guide instead.

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"**
3. Project name: `SweatMark` (or your choice)
4. Disable Google Analytics (optional)
5. Click **"Create project"**

## Step 2: Enable Services

### Enable Authentication
1. In your Firebase project, click **Authentication** → **Get Started**
2. Go to **Sign-in method** tab
3. Click **Anonymous** → Toggle **Enable** → Save
4. Click **Email/Password** → Toggle **Enable** → Save

### Enable Firestore
1. Click **Firestore Database** → **Create database**
2. Choose **Start in test mode**
3. Select your region (closest to you)
4. Click **Enable**

## Step 3: Add iOS App (if needed)

1. In Project Overview, click iOS icon
2. **iOS bundle ID**: `com.example.sweatmark` (or your choice)
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`
5. Click through the rest (no code changes needed)

## Step 4: Add Android App (if needed)

1. In Project Overview, click Android icon  
2. **Android package name**: `com.example.sweatmark`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`
5. Click through the rest

## Step 5: Get Web Config

1. In Project Overview, click Web icon (</>) 
2. App nickname: `SweatMark Web`
3. **Copy the firebaseConfig object** - you'll need this!

It looks like:
```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123"
};
```

## Step 6: Update firebase_options.dart

Replace the content of `lib/firebase_options.dart` with the configuration below, **using your values from Step 5**:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  // WEB CONFIGURATION - Replace with your values!
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // ANDROID CONFIGURATION - Get from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // iOS CONFIGURATION - Get from GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.sweatmark',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // macOS CONFIGURATION (same as iOS usually)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.sweatmark',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}
```

## Step 7: Update Firestore Security Rules

1. Go to **Firestore Database** → **Rules**
2. Replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. Click **Publish**

## Step 8: Test the App

```bash
flutter run
```

You should see the auth screen! Try:
1. **Anonymous sign-in** - Should work immediately
2. Check Firebase Console → Authentication → Users

## Troubleshooting

### "No Firebase App has been created"
- Make sure you updated `firebase_options.dart` with your actual values
- Check that all API keys are correct

### Authentication not working
- Verify Anonymous and Email/Password are enabled in Firebase Console
- Check browser console for errors

## Quick Start (Web Only)

If you just want to test quickly on web:
1. Complete Steps 1-2 (create project, enable services)
2. Complete Step 5 (get web config)
3. Update only the `web` section in `firebase_options.dart`
4. Run: `flutter run -d chrome`

---

**Need help?** The web config is the easiest to set up. Start there and test before adding iOS/Android.

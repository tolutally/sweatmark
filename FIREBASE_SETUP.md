# Firebase Setup Guide for SweatMark

This guide will walk you through setting up Firebase for SweatMark to enable cloud sync and authentication.

## Prerequisites

- Flutter SDK installed
- Firebase account (free tier is sufficient)
- FlutterFire CLI installed

## Step 1: Install FlutterFire CLI

```bash
# Install FlutterFire CLI globally
dart pub global activate flutterfire_cli
```

## Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"**
3. Enter project name: `sweatmark` (or your preferred name)
4. Disable Google Analytics (optional for this app)
5. Click **"Create project"**

## Step 3: Enable Firebase Services

### Enable Authentication

1. In Firebase Console, go to **Authentication** → **Get Started**
2. Click on **Sign-in method** tab
3. Enable **Anonymous** authentication
4. Enable **Email/Password** authentication
5. Click **Save**

### Enable Cloud Firestore

1. Go to **Firestore Database** → **Create database**
2. Choose **Start in test mode** (we'll add security rules later)
3. Select your preferred region (choose closest to your users)
4. Click **Enable**

### (Optional) Enable Firebase Storage

1. Go to **Storage** → **Get Started**
2. Start in test mode
3. Click **Done**

## Step 4: Configure FlutterFire

Run the FlutterFire configuration command from your project root:

```bash
cd /Users/tobitowoju/sweatmark
flutterfire configure
```

This will:
- Prompt you to select your Firebase project
- Ask which platforms to configure (select iOS, Android, macOS, Web as needed)
- Generate `firebase_options.dart` file automatically
- Update platform-specific configuration files

**Important**: Select the Firebase project you created in Step 2.

## Step 5: Update Firestore Security Rules

After testing, update your Firestore security rules for production:

1. Go to **Firestore Database** → **Rules** tab
2. Replace the rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. Click **Publish**

## Step 6: Verify Configuration

After running `flutterfire configure`, you should see:

1. **New file**: `lib/firebase_options.dart`
2. **Updated files**:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)
   - `macos/Runner/GoogleService-Info.plist` (macOS)

## Step 7: Test the Setup

Run the app:

```bash
flutter run
```

You should see the authentication screen. Try:
1. **Anonymous sign-in** - Should work immediately
2. **Email sign-up** - Create a test account
3. Check Firebase Console → Authentication → Users to see registered users

## Troubleshooting

### "No Firebase App '[DEFAULT]' has been created"
- Make sure you ran `flutterfire configure`
- Check that `firebase_options.dart` exists
- Verify `Firebase.initializeApp()` is called in `main.dart`

### "PERMISSION_DENIED" errors
- Check Firestore security rules
- Ensure user is authenticated before accessing Firestore
- Verify the user ID matches the document path

### Build errors on iOS/macOS
- Run `pod install` in `ios/` and `macos/` directories
- Clean build: `flutter clean && flutter pub get`

## Next Steps

After setup is complete:
1. The app will automatically use Firebase for authentication
2. Workouts will sync to Firestore when online
3. Offline mode will fall back to local storage
4. Existing local workouts will migrate on first sign-in

## Data Structure

Your Firestore database will have this structure:

```
users/
  {userId}/
    profile/
      data/
        - username
        - createdAt
        - stats
    workouts/
      {workoutId}/
        - timestamp
        - durationSeconds
        - exercises[]
```

## Support

If you encounter issues:
1. Check the [FlutterFire documentation](https://firebase.flutter.dev)
2. Review Firebase Console logs
3. Check Flutter console for error messages

# 🚀 Quick Firebase Setup (No CLI Required!)

Since you don't have Xcode installed, use this simple manual setup instead.

## Step 1: Create Firebase Project (2 minutes)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"** or **"Create a project"**
3. **Project name**: `SweatMark` (or anything you like)
4. **Google Analytics**: Disable it (not needed)
5. Click **"Create project"** → Wait for it to finish

## Step 2: Enable Authentication (1 minute)

1. In your new project, click **"Authentication"** in the left sidebar
2. Click **"Get started"**
3. Click **"Sign-in method"** tab
4. Click **"Anonymous"** → Toggle **Enable** → Click **"Save"**
5. Click **"Email/Password"** → Toggle **Enable** → Click **"Save"**

## Step 3: Enable Firestore (1 minute)

1. Click **"Firestore Database"** in the left sidebar
2. Click **"Create database"**
3. Choose **"Start in test mode"** → Click **"Next"**
4. Select your region (choose closest to you) → Click **"Enable"**

## Step 4: Get Your Web Config (2 minutes)

1. Click the **gear icon** ⚙️ next to "Project Overview" → **"Project settings"**
2. Scroll down to **"Your apps"** section
3. Click the **Web icon** `</>`
4. **App nickname**: `SweatMark Web` → Click **"Register app"**
5. You'll see a code block with `firebaseConfig` - **COPY THESE VALUES**:

```javascript
const firebaseConfig = {
  apiKey: "AIza...",                    // ← Copy this
  authDomain: "your-project.firebaseapp.com",  // ← Copy this
  projectId: "your-project-id",         // ← Copy this
  storageBucket: "your-project.appspot.com",   // ← Copy this
  messagingSenderId: "123456789",       // ← Copy this
  appId: "1:123:web:abc123"            // ← Copy this
};
```

## Step 5: Update firebase_options.dart (1 minute)

1. Open `lib/firebase_options.dart` in your editor
2. Find the `web` section (around line 30)
3. **Replace** the placeholder values with your values from Step 4:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIza...',                           // Paste YOUR apiKey
  appId: '1:123:web:abc123',                   // Paste YOUR appId
  messagingSenderId: '123456789',              // Paste YOUR messagingSenderId
  projectId: 'your-project-id',                // Paste YOUR projectId
  authDomain: 'your-project.firebaseapp.com',  // Paste YOUR authDomain
  storageBucket: 'your-project.appspot.com',   // Paste YOUR storageBucket
);
```

4. **Save the file**

## Step 6: Update Firestore Security Rules (1 minute)

1. In Firebase Console, go to **"Firestore Database"** → **"Rules"** tab
2. **Replace** the entire content with:

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

3. Click **"Publish"**

## Step 7: Test It! 🎉

Run the app on web (easiest to test):

```bash
flutter run -d chrome
```

Or if you have an Android emulator/device:

```bash
flutter run
```

You should see the **SweatMark auth screen**! Try:
- Click **"Continue as Guest"** → Should sign in
- Go to Firebase Console → **Authentication** → **Users** → You'll see your anonymous user!

---

## ✅ That's It!

You're done! The app now has:
- ✅ Cloud authentication
- ✅ Firestore database
- ✅ Offline support
- ✅ Real-time sync

## Need Help?

**Common Issues:**

1. **"No Firebase App created"** error
   - Make sure you saved `firebase_options.dart` after updating it
   - Check that all values are copied correctly (no quotes missing)

2. **Authentication not working**
   - Verify Anonymous and Email/Password are **enabled** in Firebase Console
   - Check browser console for error messages

3. **Want to test on Android/iOS later?**
   - Follow the same process but add Android/iOS app in Firebase Console
   - Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   - Update the android/ios sections in `firebase_options.dart`

---

**Total setup time: ~8 minutes** ⏱️

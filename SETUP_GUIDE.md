# Setup Guide

It seems the Flutter SDK is not installed or not in your system PATH.

## 1. Install Flutter
1. Download the Flutter SDK for Windows from [flutter.dev](https://docs.flutter.dev/get-started/install/windows).
2. Extract the zip file to a location like `C:\src\flutter`.

## 2. Update PATH
1. Search for "Edit environment variables for your account" in Windows Search.
2. Select `Path` and click **Edit**.
3. Click **New** and add the path to the `flutter\bin` directory (e.g., `C:\src\flutter\bin`).

## 3. Verify
Open a new PowerShell window and run:
```powershell
flutter doctor
```

## 4. Run the App
Once Flutter is working:
```powershell
flutter pub get
flutter run
```

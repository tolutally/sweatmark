# TestFlight Deployment Guide

This guide walks you through deploying your Sweatmark Flutter app to TestFlight for beta testing.

## Prerequisites
- **Apple Developer Account** (paid $99/year)
- **Xcode** installed on macOS
- **App Store Connect** access
- **Flutter** development environment set up

## Step 1: Configure App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **"My Apps"** → **"+"** → **"New App"**
4. Fill in app details:
   - **Platform**: iOS
   - **Name**: Sweatmark
   - **Primary Language**: English
   - **Bundle ID**: Create a new one (e.g., `com.yourname.sweatmark`)
   - **SKU**: Unique identifier (e.g., `sweatmark-ios-001`)

## Step 2: Update iOS Configuration

### Open Xcode Project
```bash
cd /Users/tobitowoju/sweatmark
open ios/Runner.xcworkspace
```

### Configure Signing in Xcode
1. Select **Runner** project in navigator
2. Go to **Signing & Capabilities** tab
3. Set:
   - **Team**: Your Apple Developer account
   - **Bundle Identifier**: Match what you created in App Store Connect
   - **Deployment Target**: iOS 12.0 or higher (recommended)

### Update App Information
1. Select **Runner** target
2. Go to **Info** tab
3. Update:
   - **Display Name**: Sweatmark
   - **Bundle Version**: 1.0.0
   - **Bundle Version String**: 1

## Step 3: Prepare for Release Build

### Update pubspec.yaml version
```yaml
version: 1.0.0+1
```

### Clean and get dependencies
```bash
flutter clean
flutter pub get
```

### Build iOS release
```bash
flutter build ios --release
```

## Step 4: Archive and Upload

### Option A: Using Xcode (Recommended)
1. In Xcode: **Product** → **Archive**
2. Wait for archive to complete
3. **Window** → **Organizer**
4. Select your archive → **Distribute App**
5. Choose **App Store Connect**
6. Select **Upload**
7. Follow the prompts to upload

### Option B: Command Line (Advanced)
```bash
# Install fastlane (optional)
sudo gem install fastlane

# Or use Xcode command line tools
xcrun altool --upload-app \
  --type ios \
  --file "path/to/your.ipa" \
  --username "your@apple.email.com" \
  --password "app-specific-password"
```

## Step 5: Set Up TestFlight

### In App Store Connect
1. Go to your app → **TestFlight** tab
2. Wait for processing (10-30 minutes typically)
3. Once processed, you'll see your build

### Add Internal Testers
1. Click **Internal Testing**
2. Add testers by email
3. They'll receive invitation emails

### Add External Testers (Optional)
1. Click **External Testing**
2. Create a test group
3. Add testers
4. **Submit for Beta App Review** (required for external testing)

## Step 6: Common Issues & Solutions

### Code Signing Issues
- Ensure certificates are valid in Xcode
- Check provisioning profiles
- Verify Team selection

### Build Failures
```bash
# Clean everything
flutter clean
rm -rf ios/Pods
rm ios/Podfile.lock
cd ios && pod install
cd .. && flutter pub get
```

### Missing App Icons
- Ensure all required icon sizes are in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Use [App Icon Generator](https://appicon.co/) for all sizes

### Privacy Permissions
Add required privacy descriptions to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for workout photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to save workout images</string>
```

## Step 7: Version Updates

### For subsequent releases:
1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # 1.0.1 is version, +2 is build number
   ```
2. Rebuild and upload following steps 3-4
3. New build will appear in TestFlight

## Useful Commands

```bash
# Check iOS build
flutter build ios --release --verbose

# Clean all Flutter/iOS cache
flutter clean && cd ios && pod cache clean --all && rm Podfile.lock && pod install

# Check connected devices
flutter devices

# Run on specific device
flutter run -d [device-id]
```

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [App Store Connect](https://appstoreconnect.apple.com)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

## Notes

- First TestFlight upload can take longer due to app review
- Internal testing (up to 100 testers) doesn't require review
- External testing requires Beta App Review (24-48 hours)
- Keep build numbers incrementing for each upload
- Test thoroughly on physical devices before uploading
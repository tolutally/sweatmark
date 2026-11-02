# Local iPhone testing

This is a Flutter application. Expo is not used.

## Tools on this Mac

- Flutter: `~/.local/share/flutter` (3.47.8).
- Xcode: `/Applications/Xcode.app` (27.1).
- Installed simulator runtimes: iOS 27.0 and 27.1.
- CocoaPods: user gems under `~/.gem/ruby/2.6.0`, version 1.16.2 to match the existing lockfile. The system Ruby requires compatible gem versions; the installer uses Command Line Tools headers for native gem compilation. Xcode remains selected for app builds.
- The iOS project now targets iOS 15 or later, as required by this Flutter toolchain. Flutter migrated supported native plugins to Swift Package Manager; unsupported plugins still use CocoaPods. Both native lockfiles are retained for reproducible builds.
- Xcode 27 opens simulators in **Device Hub**, at `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.

## Flutter compatibility

The original `phosphor_flutter` 2.1.0 extends `IconData`, which is final in current Flutter. The app uses the compatible `phosphor_icons` 3.0.1 fork with the same icon API. See https://pub.dev/packages/phosphor_icons/changelog.

The iOS entry point adopts `FlutterImplicitEngineDelegate` and the `FlutterSceneDelegate` scene manifest, required for launching on iOS 27. Firebase setup remains in the application delegate; Flutter plugins register when the engine initializes.

## Run

Open Device Hub and start an iPhone simulator, then from the project root:

```sh
./scripts/run-ios.sh
```

The script selects the single booted iPhone. If multiple iPhones are running, pass the desired UUID shown by `xcrun simctl list devices booted`:

```sh
./scripts/run-ios.sh <simulator-uuid>
```

While Flutter is running: `r` hot reloads, `R` restarts the app, and `q` quits the run session. After pulling dependency changes, run `flutter pub get` before launching again.

## Data and verification

This app's existing Firebase configuration points to **sweatmark-v1**, not an emulator. Use dedicated test accounts. Saved workouts and account changes can write real cloud data; do not use someone else's account or production records as disposable test data.

For the account-isolation check, use two test accounts. Under A, start a workout and leave a draft. Sign out, sign into B, and verify no A history/draft/custom exercises appear. Return to A and confirm its scoped draft remains available. Test restarting the app and offline behavior separately. Older unowned local files are intentionally not imported automatically; see ACCOUNT_ISOLATION.md.

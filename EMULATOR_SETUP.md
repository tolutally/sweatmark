# Android Emulator Setup Guide for SweatMark

## Step 1: Install Android Studio

1. **Download Android Studio**
   - Go to [https://developer.android.com/studio](https://developer.android.com/studio)
   - Click "Download Android Studio"
   - Accept the terms and download the installer

2. **Run the Installer**
   - Run the downloaded `.exe` file
   - Follow the setup wizard
   - **Important**: Make sure to check these options:
     - ✅ Android SDK
     - ✅ Android SDK Platform
     - ✅ Android Virtual Device (AVD)

3. **Complete Installation**
   - Choose "Standard" installation type
   - Accept all licenses
   - Wait for the SDK components to download (this may take 10-20 minutes)

## Step 2: Configure Flutter to Use Android SDK

After Android Studio is installed, Flutter needs to know where the Android SDK is located.

1. **Find Your Android SDK Path**
   - Usually located at: `C:\Users\OLUWATO2\AppData\Local\Android\Sdk`
   - Or check in Android Studio: **File → Settings → Appearance & Behavior → System Settings → Android SDK**

2. **Set Environment Variable (Optional but Recommended)**
   - Search for "Edit environment variables for your account" in Windows
   - Click "New" under User variables
   - Variable name: `ANDROID_HOME`
   - Variable value: `C:\Users\OLUWATO2\AppData\Local\Android\Sdk` (or your SDK path)
   - Click OK

3. **Verify Flutter Sees Android SDK**
   ```powershell
   flutter doctor
   ```
   - You should see ✓ for Android toolchain

## Step 3: Create an Android Virtual Device (AVD)

1. **Open AVD Manager**
   - Open Android Studio
   - Click on **Tools → Device Manager** (or the phone icon in the toolbar)

2. **Create New Virtual Device**
   - Click **"Create Device"**
   - Select a device definition (recommended: **Pixel 5** or **Pixel 6**)
   - Click **Next**

3. **Select System Image**
   - Choose a system image (recommended: **Android 13 (API 33)** or **Android 14 (API 34)**)
   - If not downloaded, click the **Download** link next to it
   - Click **Next**

4. **Configure AVD**
   - Give it a name (e.g., "SweatMark_Test")
   - **Important Settings**:
     - Graphics: **Hardware - GLES 2.0** (better performance)
     - RAM: At least **2048 MB** (if your PC has enough RAM)
   - Click **Finish**

## Step 4: Launch the Emulator

### Option A: From Android Studio
1. Open Device Manager
2. Click the ▶️ (Play) button next to your AVD
3. Wait for the emulator to boot (first launch takes 1-2 minutes)

### Option B: From Command Line
```powershell
# List available emulators
flutter emulators

# Launch specific emulator
flutter emulators --launch <emulator_id>
```

## Step 5: Run SweatMark on the Emulator

1. **Make sure the emulator is running** (you should see the Android home screen)

2. **Check Flutter can see it**
   ```powershell
   flutter devices
   ```
   - You should see your emulator listed

3. **Run the app**
   ```powershell
   cd C:\Users\OLUWATO2\sweatmark
   flutter run
   ```

4. **Or use VS Code**
   - Open the project in VS Code
   - Press `F5` or click "Run → Start Debugging"
   - Select the emulator from the device picker

## Troubleshooting

### Emulator is slow
- **Enable Hardware Acceleration**:
  - Make sure Intel HAXM or AMD Hypervisor is installed
  - Android Studio should prompt you during setup
  - Or download from: [Intel HAXM](https://github.com/intel/haxm/releases)

### "No devices found"
```powershell
# Check if emulator is running
adb devices

# If not listed, restart ADB
adb kill-server
adb start-server
```

### Flutter doctor shows issues
```powershell
flutter doctor -v
# Follow the specific instructions for each issue
```

### Can't find Android SDK
- Make sure Android Studio installation completed successfully
- Check the SDK path in Android Studio settings
- Set `ANDROID_HOME` environment variable

## Testing SweatMark Features

Once the emulator is running, you can test:
- ✅ **Navigation**: Click through all bottom nav tabs
- ✅ **Recovery Screen**: Toggle Front/Back body views
- ✅ **Start Workout**: Add exercises, log sets
- ✅ **Finish Workout**: Verify muscles turn red on recovery map
- ✅ **Exercise Library**: Search and filter exercises

## Performance Tips

1. **Keep the emulator running** between test runs (don't close it)
2. **Use Hot Reload** (`r` in terminal or Save in VS Code) for quick UI changes
3. **Use Hot Restart** (`R` in terminal) if state gets weird
4. **Close other heavy apps** while running the emulator

---

**Need help?** Run `flutter doctor` and share the output if you encounter issues!

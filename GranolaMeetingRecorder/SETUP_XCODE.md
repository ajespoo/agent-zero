# 🔧 Xcode Project Setup Guide

This guide will help you create the Xcode project and link all the source files we've created.

## Prerequisites

- macOS with Xcode 15.0+ installed
- Apple Developer account (free tier is fine for device testing)

## Step-by-Step Setup

### 1. Create New Xcode Project

1. Open **Xcode**
2. Select **File → New → Project** (or press ⌘⇧N)
3. Choose **iOS → App**
4. Click **Next**

### 2. Configure Project Settings

Enter the following details:

- **Product Name**: `GranolaMeetingRecorder`
- **Team**: Select your development team
- **Organization Identifier**: `com.yourname` (or your preferred identifier)
- **Bundle Identifier**: Will auto-generate as `com.yourname.GranolaMeetingRecorder`
- **Interface**: **SwiftUI**
- **Language**: **Swift**
- **Storage**: **SwiftData**
- **Include Tests**: ✅ (recommended)

Click **Next** and save the project in the `GranolaMeetingRecorder` directory (replace the default files).

### 3. Delete Default Files

Xcode creates some default files. Delete these:

1. Right-click on `ContentView.swift` in the project navigator
2. Select **Delete** → **Move to Trash**
3. Repeat for `Item.swift` (the default SwiftData model)

### 4. Add Source Files to Project

#### Method A: Drag and Drop (Easiest)

1. In Finder, navigate to the `GranolaMeetingRecorder` folder
2. Drag the following folders into Xcode's project navigator:
   - `App/`
   - `Core/`
   - `Models/`
   - `Views/`
   - `Utilities/`
3. When prompted, ensure:
   - ✅ **Copy items if needed** is UNCHECKED (files are already in the right place)
   - ✅ **Create groups** is selected
   - ✅ Target **GranolaMeetingRecorder** is selected

#### Method B: Add Files Manually

1. Right-click on the `GranolaMeetingRecorder` group in project navigator
2. Select **Add Files to "GranolaMeetingRecorder"...**
3. Navigate to each folder and select all `.swift` files
4. Repeat for all folders

### 5. Add Resources

1. Right-click on project navigator
2. Select **Add Files to "GranolaMeetingRecorder"...**
3. Navigate to `Resources/` folder
4. Select `Info.plist` and `Config.plist.example`
5. Ensure target membership is correct

### 6. Configure Info.plist

1. Select the project in the navigator (blue icon at top)
2. Select the **GranolaMeetingRecorder** target
3. Go to **Info** tab
4. Click **Custom iOS Target Properties**
5. If using the Info.plist we created:
   - At the bottom, click **+** to add a new key
   - Find and set: **"Generate Info.plist File"** to **NO**
   - Set **Info.plist File** path to: `GranolaMeetingRecorder/Resources/Info.plist`

### 7. Set Deployment Target

1. Select the project in navigator
2. Select **GranolaMeetingRecorder** target
3. Go to **General** tab
4. Set **Minimum Deployments** → **iOS** to **17.0**

### 8. Configure Signing

1. In **Signing & Capabilities** tab
2. Check **Automatically manage signing**
3. Select your **Team**
4. Xcode will automatically generate a provisioning profile

### 9. Add Required Capabilities

1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add:
   - **Background Modes** → Enable **Audio**

The calendar and microphone permissions are already in Info.plist.

### 10. Configure API Key

Choose one of these methods:

#### Option A: Environment Variable (Recommended for Development)

1. Select **Product → Scheme → Edit Scheme** (or press ⌘<)
2. Select **Run** on the left
3. Go to **Arguments** tab
4. Under **Environment Variables**, click **+**
5. Add:
   - **Name**: `OPENAI_API_KEY`
   - **Value**: `your-actual-openai-api-key`

#### Option B: Config.plist File

1. Copy `Config.plist.example` to `Config.plist`:
   ```bash
   cp Resources/Config.plist.example Resources/Config.plist
   ```
2. Open `Config.plist` in Xcode
3. Replace `your-openai-api-key-here` with your actual key
4. Add `Config.plist` to target if not already added

### 11. Verify File Structure

Your Xcode project navigator should look like this:

```
GranolaMeetingRecorder/
├── App/
│   └── GranolaMeetingRecorderApp.swift
├── Core/
│   ├── Audio/
│   │   └── AudioRecorder.swift
│   ├── Calendar/
│   │   └── CalendarManager.swift
│   └── Network/
│       ├── WhisperService.swift
│       └── AIService.swift
├── Models/
│   ├── Meeting.swift
│   └── CalendarEvent.swift
├── Views/
│   ├── MeetingsListView.swift
│   ├── CalendarView.swift
│   ├── RecordingView.swift
│   └── MeetingDetailView.swift
├── Utilities/
│   └── Config.swift
└── Resources/
    ├── Info.plist
    └── Config.plist
```

### 12. Build and Run

1. Select a simulator or connected device from the scheme selector
   - **Recommended**: iPhone 15 Pro simulator or physical device
2. Press **⌘R** to build and run
3. The app should compile and launch

### 13. Grant Permissions

On first launch, the app will request:

1. **Microphone access** - Tap **Allow**
2. **Calendar access** - Tap **Allow**

## 🧪 Test the Setup

### Quick Test Checklist

1. **App Launches**: ✅ No crashes on launch
2. **Tabs Visible**: ✅ See Meetings, Calendar, Settings tabs
3. **Calendar Access**: ✅ Go to Calendar tab, grant permission
4. **Create Meeting**: ✅ Tap + button, create test meeting
5. **Start Recording**: ✅ Start a 10-second test recording
6. **Stop Recording**: ✅ Stop and save
7. **View Meeting**: ✅ Tap meeting to view details
8. **Transcription**: ✅ Wait for "Transcribing..." status
9. **Summary**: ✅ Wait for AI summary to generate

## 🐛 Common Issues

### Build Errors

**"Cannot find type 'Meeting' in scope"**
- **Fix**: Make sure all files are added to the target
- Check target membership in File Inspector (right panel)

**"Module compiled with Swift X.X cannot be imported by Swift Y.Y"**
- **Fix**: Clean build folder (⌘⇧K) and rebuild

### Runtime Errors

**"API Key Not Configured" alert**
- **Fix**: Follow step 10 to configure your OpenAI API key

**Calendar not showing events**
- **Fix**: Open iOS Settings → Privacy → Calendars → Enable for the app

**Microphone not working**
- **Fix**: Open iOS Settings → Privacy → Microphone → Enable for the app

## 📱 Running on Physical Device

### Requirements

- Apple Developer account (free tier works)
- iOS 17+ device
- USB cable or WiFi sync enabled

### Steps

1. Connect your iPhone to your Mac
2. Select your device from the scheme selector
3. In **Signing & Capabilities**, ensure your team is selected
4. Press **⌘R** to build and run
5. If prompted on device, go to **Settings → General → VPN & Device Management**
6. Trust your developer certificate

## 🔄 Troubleshooting Xcode

### Clean Build

If you encounter weird issues:

1. **Clean Build Folder**: Press **⌘⇧K**
2. **Delete Derived Data**:
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete the `GranolaMeetingRecorder-xxx` folder
3. Rebuild: Press **⌘B**

### Reset Simulator

If simulator acts strangely:

1. **Simulator → Device → Erase All Content and Settings**
2. Rebuild and run

## ✅ Success!

If the app builds and runs successfully, you're all set!

Read the main [README.md](README.md) for usage instructions and features.

## 📚 Next Steps

- [ ] Configure your OpenAI API key
- [ ] Test recording a meeting
- [ ] Customize the app for your needs
- [ ] Read the architecture documentation
- [ ] Star the repo if you found it useful! ⭐

## 🆘 Need Help?

If you encounter issues not covered here:

1. Check [GitHub Issues](https://github.com/yourusername/GranolaMeetingRecorder/issues)
2. Review Apple's [SwiftUI documentation](https://developer.apple.com/documentation/swiftui)
3. Check [SwiftData documentation](https://developer.apple.com/documentation/swiftdata)

---

**Happy coding! 🎉**

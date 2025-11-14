# 🎙️ Granola Meeting Recorder

A native iOS app inspired by [Granola](https://www.granola.so/) that records meetings, automatically transcribes them using OpenAI Whisper, and generates AI-powered summaries with GPT-4.

## ✨ Features

- 📅 **Calendar Integration** - View and record upcoming meetings from your iOS calendar
- 🎤 **High-Quality Recording** - Record meetings with professional audio quality (44.1kHz AAC)
- 📝 **AI Transcription** - Automatic transcription using OpenAI Whisper API
- 🤖 **Smart Summaries** - AI-generated meeting summaries with action items
- 💾 **Local Storage** - All recordings stored securely on device using SwiftData
- 🎨 **Modern UI** - Beautiful SwiftUI interface with live audio visualization
- 🔒 **Privacy-First** - No cloud storage, all data stays on your device

## 🏗️ Architecture

Built with **modern iOS development best practices**:

### Technology Stack

- **Swift 5.9+** with modern concurrency (async/await)
- **SwiftUI** for declarative UI
- **SwiftData** (iOS 17+) for data persistence
- **AVFoundation** for audio recording
- **EventKit** for calendar integration
- **OpenAI Whisper API** for cloud transcription
- **OpenAI GPT-4o-mini** for AI summaries

### Design Patterns

- **MVVM Architecture** - Clean separation of concerns
- **Dependency Injection** - Testable, modular services
- **Protocol-Oriented Programming** - Flexible abstractions
- **Repository Pattern** - SwiftData as data layer

### Project Structure

```
GranolaMeetingRecorder/
├── App/
│   └── GranolaMeetingRecorderApp.swift    # App entry point
├── Core/
│   ├── Audio/
│   │   └── AudioRecorder.swift            # Recording service
│   ├── Calendar/
│   │   └── CalendarManager.swift          # Calendar integration
│   └── Network/
│       ├── WhisperService.swift           # Transcription API
│       └── AIService.swift                # Summarization API
├── Models/
│   ├── Meeting.swift                      # SwiftData model
│   └── CalendarEvent.swift                # Calendar model
├── Views/
│   ├── MeetingsListView.swift             # Main meeting list
│   ├── CalendarView.swift                 # Calendar view
│   ├── RecordingView.swift                # Live recording UI
│   ├── MeetingDetailView.swift            # Transcript & summary
│   └── Components/                        # Reusable components
├── Utilities/
│   └── Config.swift                       # Configuration
└── Resources/
    ├── Info.plist                         # Permissions
    └── Config.plist.example               # API key template
```

## 📋 Requirements

- **iOS 17.0+** (for SwiftData support)
- **Xcode 15.0+**
- **OpenAI API Key** ([Get one here](https://platform.openai.com/api-keys))
- **Physical device recommended** for best audio quality

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/GranolaMeetingRecorder.git
cd GranolaMeetingRecorder
```

### 2. Configure OpenAI API Key

You have **two options** to configure your API key:

#### Option A: Environment Variable (Recommended)

In Xcode, go to **Product → Scheme → Edit Scheme → Run → Arguments**:

Add environment variable:
```
OPENAI_API_KEY = your-actual-api-key-here
```

#### Option B: Config.plist File

1. Copy the example config file:
```bash
cp GranolaMeetingRecorder/Resources/Config.plist.example GranolaMeetingRecorder/Resources/Config.plist
```

2. Open `Config.plist` and replace `your-openai-api-key-here` with your actual key:
```xml
<key>OPENAI_API_KEY</key>
<string>sk-proj-abc123...</string>
```

3. **⚠️ Important**: Add `Config.plist` to `.gitignore` to prevent committing your API key:
```bash
echo "GranolaMeetingRecorder/Resources/Config.plist" >> .gitignore
```

#### Option C: Hardcode in Config.swift (Development Only)

Open `GranolaMeetingRecorder/Utilities/Config.swift` and replace the placeholder:
```swift
static var openAIAPIKey: String {
    return "sk-proj-your-actual-key-here"
}
```

**⚠️ Never commit hardcoded API keys to version control!**

### 3. Open in Xcode

```bash
open GranolaMeetingRecorder.xcodeproj
```

Or drag the project folder into Xcode.

### 4. Configure Project Settings

1. Select the project in Xcode navigator
2. Under **Signing & Capabilities**, select your development team
3. Change **Bundle Identifier** if needed (e.g., `com.yourname.granola`)

### 5. Build and Run

1. Select your device or simulator (iPhone 15+ recommended)
2. Press **⌘R** to build and run
3. Grant **Microphone** and **Calendar** permissions when prompted

## 📱 Usage

### Recording a Meeting

#### From Calendar:
1. Open the **Calendar** tab
2. Tap on an upcoming meeting
3. Tap **"Record This Meeting"**
4. Recording starts automatically

#### Manual Recording:
1. Go to **Meetings** tab
2. Tap **+** button
3. Enter meeting title and participants
4. Tap **"Start Recording"**

### During Recording

- **Live timer** shows recording duration
- **Audio waveform** visualizes sound levels
- **Stop & Save** button to finish recording

### After Recording

The app automatically:
1. 📝 **Transcribes** the audio using Whisper API
2. 🤖 **Generates** AI summary with action items
3. 💾 **Saves** everything locally

### Viewing Recordings

1. Tap any meeting in the **Meetings** tab
2. View **Summary**, **Transcript**, or **Details**
3. Tap play button to listen to audio
4. Swipe left on meeting for share/delete options

## ⚙️ Configuration

### Audio Settings

Edit `Config.swift` to customize recording quality:

```swift
enum Recording {
    static let sampleRate: Double = 44100.0  // CD quality
    static let numberOfChannels: Int = 1     // Mono
    static let maxDuration: TimeInterval = 4 * 60 * 60  // 4 hours
}
```

### AI Model Settings

```swift
enum AI {
    static let model = "gpt-4o-mini"  // Fast & cost-effective
    static let temperature: Double = 0.3
    static let maxTokens = 1500
}
```

To use GPT-4 for higher quality summaries:
```swift
static let model = "gpt-4"
```

## 🧪 Testing

### Unit Tests

```bash
xcodebuild test -scheme GranolaMeetingRecorder -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manual Testing Checklist

- [ ] Grant microphone permission
- [ ] Grant calendar permission
- [ ] Record 30-second test meeting
- [ ] Verify transcription completes
- [ ] Verify summary generates
- [ ] Test audio playback
- [ ] Test meeting deletion
- [ ] Test search functionality

## 💰 Cost Estimates

### OpenAI API Pricing (as of 2024)

**Whisper API** (Transcription):
- $0.006 per minute of audio
- 1-hour meeting = **$0.36**

**GPT-4o-mini** (Summarization):
- ~$0.01 per meeting summary
- Very affordable for regular use

**Total cost per 1-hour meeting: ~$0.37**

### Tips to Reduce Costs

1. Use **GPT-4o-mini** instead of GPT-4 (20x cheaper)
2. Only transcribe important meetings
3. Use shorter audio clips for testing
4. Monitor usage at [OpenAI Usage Dashboard](https://platform.openai.com/usage)

## 🔒 Privacy & Security

- ✅ All recordings stored **locally on device**
- ✅ Audio only sent to OpenAI for transcription
- ✅ API keys stored securely (Keychain recommended for production)
- ✅ No analytics or tracking
- ✅ User controls all data deletion

### Security Best Practices

1. **Never commit API keys** to version control
2. Use **environment variables** or **Keychain** for production
3. Enable **Face ID/Touch ID** for app access (future feature)
4. Regularly rotate your OpenAI API keys
5. Set usage limits on OpenAI dashboard

## 🚧 Roadmap

### Phase 1: Core Features ✅
- [x] Audio recording with visualization
- [x] Calendar integration
- [x] Whisper transcription
- [x] GPT-4 summaries
- [x] Local data persistence

### Phase 2: Enhancement 🚧
- [ ] Background recording support
- [ ] Export to PDF/Word
- [ ] Speaker diarization
- [ ] Real-time transcription
- [ ] Search across all transcripts

### Phase 3: Advanced Features 🔮
- [ ] iCloud sync (optional)
- [ ] Siri shortcuts integration
- [ ] Apple Watch companion app
- [ ] Meeting templates
- [ ] Integration with Notion/Slack

## 🐛 Troubleshooting

### "API Key Not Configured" Error

**Solution**: Follow step 2 in Setup Instructions to configure your API key.

### Transcription Fails

**Possible causes**:
1. Invalid API key → Check OpenAI dashboard
2. File too large (>25MB) → Record shorter meetings
3. Network issue → Check internet connection
4. Rate limit → Wait and retry

### Audio Quality Issues

**Solutions**:
1. Use physical device (not simulator)
2. Hold phone closer to speakers
3. Use external microphone for better quality
4. Check microphone permissions in Settings

### Calendar Not Showing Events

**Solutions**:
1. Grant calendar permission in Settings → Privacy
2. Check events exist in iOS Calendar app
3. Try pulling to refresh

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift style guide
- Use meaningful commit messages
- Add comments for complex logic
- Update README for new features
- Test on physical device

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Granola](https://www.granola.so/)
- Built with [OpenAI Whisper](https://openai.com/research/whisper) and [GPT-4](https://openai.com/gpt-4)
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/GranolaMeetingRecorder/issues)
- **Email**: your-email@example.com
- **Twitter**: [@yourhandle](https://twitter.com/yourhandle)

---

**Built with ❤️ using Swift and SwiftUI**

*Last updated: November 2024*

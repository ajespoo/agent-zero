# 🏛️ Architecture Documentation

## Overview

Granola Meeting Recorder is built using modern iOS development best practices with a clean, modular architecture that separates concerns and promotes testability.

## Architecture Pattern: MVVM + Clean Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Views (SwiftUI)                   │
│  ┌────────────────┐  ┌────────────────────────────┐ │
│  │ MeetingsListView│  │ RecordingView              │ │
│  │ CalendarView    │  │ MeetingDetailView          │ │
│  └────────────────┘  └────────────────────────────┘ │
└───────────────────────┬─────────────────────────────┘
                        │ @EnvironmentObject
                        │ @StateObject
┌───────────────────────▼─────────────────────────────┐
│              View Models / Services                  │
│  ┌────────────────┐  ┌────────────────────────────┐ │
│  │ AudioRecorder  │  │ CalendarManager            │ │
│  │ WhisperService │  │ AIService                  │ │
│  └────────────────┘  └────────────────────────────┘ │
└───────────────────────┬─────────────────────────────┘
                        │ Business Logic
                        │ API Calls
┌───────────────────────▼─────────────────────────────┐
│                 Core Services                        │
│  ┌────────────────┐  ┌────────────────────────────┐ │
│  │ AVFoundation   │  │ EventKit                   │ │
│  │ URLSession     │  │ FileManager                │ │
│  └────────────────┘  └────────────────────────────┘ │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│              Data Layer (SwiftData)                  │
│  ┌────────────────────────────────────────────────┐ │
│  │           ModelContainer & Context             │ │
│  │  ┌──────────┐  ┌─────────────────────────────┐│ │
│  │  │ Meeting  │  │ Persistent Storage          ││ │
│  │  └──────────┘  └─────────────────────────────┘│ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Layer Breakdown

### 1. Presentation Layer (Views)

**Technology**: SwiftUI

**Responsibilities**:
- Display UI components
- Handle user interactions
- Observe state changes
- Navigate between screens

**Key Views**:
- `MeetingsListView` - Main list of recorded meetings
- `CalendarView` - Shows upcoming calendar events
- `RecordingView` - Live recording interface with waveform
- `MeetingDetailView` - Displays transcript and AI summary

**Design Patterns**:
- Declarative UI with SwiftUI
- Environment objects for dependency injection
- Observable objects for reactive updates

### 2. Business Logic Layer (Services)

**Technology**: Swift with async/await

**Responsibilities**:
- Handle complex business logic
- Manage external API calls
- Process audio and data
- Maintain app state

**Key Services**:

#### AudioRecorder
```swift
@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording: Bool
    @Published var currentTime: TimeInterval
    @Published var audioLevel: Float

    func startRecording() async throws -> URL
    func stopRecording() throws -> URL
}
```

**Features**:
- High-quality AAC recording (44.1kHz)
- Real-time audio level monitoring
- Automatic file management
- Permission handling

#### WhisperService
```swift
@MainActor
final class WhisperService: ObservableObject {
    @Published var isTranscribing: Bool
    @Published var progress: Double

    func transcribe(fileURL: URL) async throws -> String
}
```

**Features**:
- Multipart form data upload
- Progress tracking
- Error handling with retry logic
- File size validation

#### AIService
```swift
@MainActor
final class AIService: ObservableObject {
    @Published var isProcessing: Bool

    func summarize(transcript: String) async throws -> String
    func extractActionItems(transcript: String) async throws -> [String]
}
```

**Features**:
- GPT-4 integration
- Structured summary generation
- Action item extraction
- Token estimation

#### CalendarManager
```swift
@MainActor
final class CalendarManager: ObservableObject {
    @Published var events: [CalendarEvent]
    @Published var authorizationStatus: EKAuthorizationStatus

    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEvent]
}
```

**Features**:
- EventKit integration
- Permission management
- Event filtering and grouping
- iOS 17+ compatibility

### 3. Data Layer (Models)

**Technology**: SwiftData (iOS 17+)

**Responsibilities**:
- Define data models
- Handle persistence
- Manage relationships
- Query data

**Key Models**:

#### Meeting (SwiftData Model)
```swift
@Model
final class Meeting {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var status: RecordingStatus
    var audioFilePath: String?
    var transcript: String?
    var summary: String?
    var actionItems: [String]
    var participants: [String]
    // ... more properties
}
```

**Features**:
- Automatic persistence
- Type-safe queries
- Computed properties
- Sample data for previews

#### CalendarEvent (Value Type)
```swift
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    // ... more properties
}
```

**Features**:
- Immutable value type
- EventKit conversion
- Computed properties for UI

## Data Flow

### Recording Flow

```
1. User taps "Record" button
   ↓
2. RecordingView appears
   ↓
3. AudioRecorder.startRecording()
   ↓
4. Meeting model created in SwiftData
   ↓
5. Audio recorded to local file
   ↓
6. User taps "Stop"
   ↓
7. AudioRecorder.stopRecording()
   ↓
8. Meeting.status = .processing
   ↓
9. WhisperService.transcribe(audioURL)
   ↓
10. Meeting.transcript = result
    ↓
11. AIService.summarize(transcript)
    ↓
12. Meeting.summary = result
    ↓
13. Meeting.status = .completed
```

### Data Persistence Flow

```
SwiftUI View
    ↓ @Query
ModelContext (SwiftData)
    ↓
ModelContainer
    ↓
Persistent Storage (SQLite)
```

## Threading Model

### Main Thread (@MainActor)
- All UI updates
- Published property changes
- ObservableObject updates

### Background Threads
- API network calls (URLSession)
- Audio processing
- File I/O operations

**Concurrency Pattern**:
```swift
Task {
    // Background work
    let result = try await networkCall()

    await MainActor.run {
        // Update UI on main thread
        self.data = result
    }
}
```

## Dependency Injection

Using SwiftUI's environment system:

```swift
@main
struct GranolaMeetingRecorderApp: App {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var calendarManager = CalendarManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioRecorder)
                .environmentObject(calendarManager)
        }
    }
}
```

**Benefits**:
- Testable (can inject mocks)
- Modular
- Single source of truth

## Error Handling

### Strategy: Typed Errors

```swift
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case noActiveRecording

    var errorDescription: String? {
        // User-friendly messages
    }
}
```

**Error Propagation**:
```swift
do {
    try await service.perform()
} catch let error as ServiceError {
    // Handle specific error
} catch {
    // Handle generic error
}
```

## File Organization

```
GranolaMeetingRecorder/
├── App/                    # App entry point
├── Core/                   # Business logic
│   ├── Audio/              # Recording services
│   ├── Calendar/           # Calendar services
│   ├── Network/            # API services
│   └── Storage/            # File management
├── Models/                 # Data models
├── Views/                  # SwiftUI views
│   └── Components/         # Reusable UI components
├── Utilities/              # Helpers & extensions
└── Resources/              # Assets & config
```

## Testing Strategy

### Unit Tests
- Test services in isolation
- Mock network calls
- Test business logic

### Integration Tests
- Test SwiftData persistence
- Test API integration
- Test audio recording

### UI Tests
- Test user flows
- Test navigation
- Test permissions

## Performance Optimizations

### Memory Management
- Lazy loading of audio files
- Pagination for large lists
- Automatic cleanup of old recordings

### Network Optimization
- Concurrent API calls where possible
- Progress tracking for long operations
- Retry logic with exponential backoff

### UI Performance
- List virtualization (SwiftUI handles automatically)
- Lazy views for heavy content
- Debounced search

## Security Considerations

### API Key Management
1. Environment variables (dev)
2. Keychain (production)
3. Never in source control

### Data Privacy
- Local-first architecture
- No analytics/tracking
- User controls all data

### Permissions
- Just-in-time permission requests
- Clear permission descriptions
- Graceful degradation

## Future Architecture Improvements

### Phase 2
- [ ] Add Repository pattern for data access
- [ ] Implement Coordinator pattern for navigation
- [ ] Add Combine for reactive programming

### Phase 3
- [ ] CloudKit sync (optional)
- [ ] Background task processing
- [ ] Widget extensions

## Design Principles

1. **Separation of Concerns** - Each component has a single responsibility
2. **Dependency Inversion** - Depend on abstractions, not concretions
3. **Single Source of Truth** - SwiftData as the source of truth
4. **Immutability** - Value types where possible
5. **Protocol-Oriented** - Use protocols for flexibility

## API Design

### Service Protocols (Future)

```swift
protocol AudioRecordingService {
    func startRecording() async throws -> URL
    func stopRecording() throws -> URL
}

protocol TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String
}
```

This allows easy mocking and swapping of implementations.

## Conclusion

The architecture is designed to be:
- ✅ **Maintainable** - Clear separation of concerns
- ✅ **Testable** - Dependency injection
- ✅ **Scalable** - Modular design
- ✅ **Modern** - Latest Swift/SwiftUI features
- ✅ **Production-Ready** - Error handling, security, performance

---

**Questions or suggestions?** Open an issue on GitHub!

//
//  GranolaMeetingRecorderApp.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import SwiftUI
import SwiftData

@main
struct GranolaMeetingRecorderApp: App {
    // MARK: - State Objects

    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var whisperService = WhisperService(apiKey: Config.openAIAPIKey)
    @StateObject private var aiService = AIService(apiKey: Config.openAIAPIKey)

    // MARK: - SwiftData Container

    let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        do {
            // Configure SwiftData model container
            let schema = Schema([
                Meeting.self,
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioRecorder)
                .environmentObject(calendarManager)
                .environmentObject(whisperService)
                .environmentObject(aiService)
                .modelContainer(modelContainer)
                .onAppear {
                    setupApp()
                }
        }
    }

    // MARK: - Setup

    private func setupApp() {
        // Validate API key configuration
        if !Config.isAPIKeyConfigured() {
            print("⚠️ WARNING: OpenAI API key not configured!")
            print("Please set your API key in Config.swift or as an environment variable")
        }

        #if DEBUG
        if Config.Debug.logging {
            print("✅ Granola Meeting Recorder launched")
            print("📱 App Version: \(Config.App.version)")
            print("🔑 API Key Configured: \(Config.isAPIKeyConfigured())")
        }
        #endif
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]

    @State private var showingAPIKeyAlert = false

    var body: some View {
        TabView {
            // Meetings List Tab
            MeetingsListView()
                .tabItem {
                    Label("Meetings", systemImage: "list.bullet")
                }

            // Calendar Tab
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            checkAPIKeyConfiguration()
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please configure your OpenAI API key in the Settings tab to use transcription and AI summary features.")
        }
    }

    private func checkAPIKeyConfiguration() {
        if !Config.isAPIKeyConfigured() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingAPIKeyAlert = true
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    ContentView()
        .environmentObject(AudioRecorder())
        .environmentObject(CalendarManager())
        .environmentObject(WhisperService(apiKey: "preview-key"))
        .environmentObject(AIService(apiKey: "preview-key"))
        .modelContainer(for: Meeting.self, inMemory: true)
}

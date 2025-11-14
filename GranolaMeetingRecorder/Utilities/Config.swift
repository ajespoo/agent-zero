//
//  Config.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import Foundation

/// Application configuration and constants
enum Config {
    // MARK: - OpenAI Configuration

    /// OpenAI API Key
    /// IMPORTANT: Replace with your actual API key or use environment variables
    static var openAIAPIKey: String {
        // Try to read from environment variable first
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty {
            return apiKey
        }

        // Try to read from Config.plist
        if let apiKey = readFromPlist(key: "OPENAI_API_KEY"), !apiKey.isEmpty {
            return apiKey
        }

        // Fallback: Return placeholder (user must replace this)
        return "your-openai-api-key-here"
    }

    // MARK: - App Configuration

    enum App {
        static let name = "Granola Meeting Recorder"
        static let version = "1.0.0"
        static let bundleIdentifier = "com.granola.meetingrecorder"
    }

    // MARK: - Recording Settings

    enum Recording {
        /// Maximum recording duration in seconds (4 hours)
        static let maxDuration: TimeInterval = 4 * 60 * 60

        /// Audio file format
        static let fileExtension = "m4a"

        /// Sample rate for recording
        static let sampleRate: Double = 44100.0

        /// Number of audio channels
        static let numberOfChannels: Int = 1

        /// Audio quality
        static let audioQuality = "high"
    }

    // MARK: - Transcription Settings

    enum Transcription {
        /// Maximum file size for Whisper API (25MB)
        static let maxFileSize: Int64 = 25 * 1024 * 1024

        /// Whisper model to use
        static let model = "whisper-1"

        /// Default language for transcription (nil = auto-detect)
        static let defaultLanguage: String? = nil

        /// Chunk size for long audio files (in seconds)
        static let chunkDuration: TimeInterval = 10 * 60 // 10 minutes
    }

    // MARK: - AI Settings

    enum AI {
        /// GPT model for summarization
        static let model = "gpt-4o-mini"

        /// Temperature for summary generation
        static let temperature: Double = 0.3

        /// Max tokens for summary
        static let maxTokens = 1500

        /// Token estimation ratio (chars per token)
        static let charsPerToken = 4
    }

    // MARK: - Calendar Settings

    enum Calendar {
        /// Number of days to fetch for upcoming meetings
        static let upcomingDays = 7

        /// Minimum meeting duration to show (in minutes)
        static let minDuration = 5

        /// Automatically link meetings by title similarity threshold
        static let titleSimilarityThreshold = 0.8
    }

    // MARK: - UI Settings

    enum UI {
        /// Animation duration
        static let animationDuration: Double = 0.3

        /// Debounce delay for search (seconds)
        static let searchDebounceDelay: Double = 0.5

        /// Number of items per page
        static let itemsPerPage = 20
    }

    // MARK: - Storage Settings

    enum Storage {
        /// Directory name for audio files
        static let audioDirectoryName = "Recordings"

        /// Enable automatic cleanup of old recordings
        static let autoCleanup = false

        /// Number of days before auto-cleanup
        static let cleanupAfterDays = 90
    }

    // MARK: - Feature Flags

    enum Features {
        /// Enable speaker diarization (future feature)
        static let speakerDiarization = false

        /// Enable real-time transcription
        static let realtimeTranscription = false

        /// Enable cloud backup
        static let cloudBackup = false

        /// Enable export to PDF
        static let pdfExport = true

        /// Enable export to text
        static let textExport = true
    }

    // MARK: - Helper Methods

    /// Read configuration value from Config.plist
    private static func readFromPlist(key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return config[key] as? String
    }

    /// Validate that API key is configured
    static func isAPIKeyConfigured() -> Bool {
        let key = openAIAPIKey
        return !key.isEmpty && key != "your-openai-api-key-here"
    }
}

// MARK: - Developer/Debug Settings

#if DEBUG
extension Config {
    enum Debug {
        /// Enable debug logging
        static let logging = true

        /// Use mock data for previews
        static let useMockData = true

        /// Skip API calls in development
        static let skipAPICalls = false

        /// Show debug UI elements
        static let showDebugUI = true
    }
}
#endif

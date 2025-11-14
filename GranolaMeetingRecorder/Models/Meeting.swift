//
//  Meeting.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import Foundation
import SwiftData

/// Represents a meeting that can be recorded, transcribed, and summarized
@Model
final class Meeting {
    // MARK: - Properties

    /// Unique identifier for the meeting
    var id: UUID

    /// Meeting title (from calendar or user-defined)
    var title: String

    /// Optional calendar event identifier from EventKit
    var calendarEventID: String?

    /// Date and time when the meeting occurred
    var date: Date

    /// Duration of the meeting in seconds
    var duration: TimeInterval

    /// Current recording status
    var status: RecordingStatus

    /// File path to the audio recording (relative to documents directory)
    var audioFilePath: String?

    /// Size of the audio file in bytes
    var audioFileSize: Int64

    /// Transcript text (populated after transcription)
    var transcript: String?

    /// AI-generated summary (populated after processing)
    var summary: String?

    /// Key action items extracted from the meeting
    var actionItems: [String]

    /// Participants in the meeting (from calendar or manual entry)
    var participants: [String]

    /// Optional notes added by the user
    var notes: String?

    /// Timestamp when the meeting was created in the app
    var createdAt: Date

    /// Timestamp of last update
    var updatedAt: Date

    /// Transcription processing progress (0.0 to 1.0)
    var transcriptionProgress: Double

    /// Whether the transcription has been completed
    var isTranscribed: Bool

    /// Whether the AI summary has been generated
    var isSummarized: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        calendarEventID: String? = nil,
        date: Date,
        duration: TimeInterval = 0,
        status: RecordingStatus = .scheduled,
        audioFilePath: String? = nil,
        audioFileSize: Int64 = 0,
        transcript: String? = nil,
        summary: String? = nil,
        actionItems: [String] = [],
        participants: [String] = [],
        notes: String? = nil,
        transcriptionProgress: Double = 0.0,
        isTranscribed: Bool = false,
        isSummarized: Bool = false
    ) {
        self.id = id
        self.title = title
        self.calendarEventID = calendarEventID
        self.date = date
        self.duration = duration
        self.status = status
        self.audioFilePath = audioFilePath
        self.audioFileSize = audioFileSize
        self.transcript = transcript
        self.summary = summary
        self.actionItems = actionItems
        self.participants = participants
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.transcriptionProgress = transcriptionProgress
        self.isTranscribed = isTranscribed
        self.isSummarized = isSummarized
    }

    // MARK: - Computed Properties

    /// Formatted duration string (e.g., "1h 23m")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Audio file URL in the documents directory
    var audioFileURL: URL? {
        guard let audioFilePath = audioFilePath else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(audioFilePath)
    }

    /// Formatted file size (e.g., "12.5 MB")
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: audioFileSize)
    }

    // MARK: - Methods

    /// Update the last modified timestamp
    func markAsUpdated() {
        updatedAt = Date()
    }

    /// Check if the meeting can be deleted
    var canBeDeleted: Bool {
        return status != .recording
    }
}

// MARK: - Recording Status

/// Represents the current state of a meeting recording
enum RecordingStatus: String, Codable {
    case scheduled      // Meeting is scheduled but not started
    case recording      // Currently recording
    case processing     // Recording finished, processing audio
    case transcribing   // Sending to Whisper API for transcription
    case summarizing    // Generating AI summary
    case completed      // All processing complete
    case failed         // An error occurred during processing
    case cancelled      // Recording was cancelled by user
}

// MARK: - Extensions

extension Meeting {
    /// Create a sample meeting for previews and testing
    static var sample: Meeting {
        Meeting(
            title: "Product Planning Meeting",
            date: Date(),
            duration: 3600,
            status: .completed,
            audioFileSize: 15_728_640,
            transcript: "This is a sample transcript of the meeting discussion...",
            summary: "The team discussed Q1 product roadmap and prioritized features for the upcoming release.",
            actionItems: [
                "Schedule follow-up with design team",
                "Review user feedback survey results",
                "Prepare technical spec for feature X"
            ],
            participants: ["Alice Johnson", "Bob Smith", "Carol White"],
            isTranscribed: true,
            isSummarized: true
        )
    }

    /// Create a recording meeting for previews
    static var recording: Meeting {
        Meeting(
            title: "Daily Standup",
            date: Date(),
            duration: 300,
            status: .recording,
            participants: ["Team Members"]
        )
    }
}

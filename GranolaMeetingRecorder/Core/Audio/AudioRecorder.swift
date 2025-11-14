//
//  AudioRecorder.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import AVFoundation
import Foundation
import Combine

/// Errors that can occur during audio recording
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case noActiveRecording
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record meetings."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .noActiveRecording:
            return "No active recording session."
        case .fileNotFound:
            return "Audio file not found."
        }
    }
}

/// Manages audio recording sessions using AVAudioRecorder
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var currentTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var error: AudioRecorderError?

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = .sharedInstance()
    private var levelTimer: Timer?
    private var timeTimer: Timer?
    private var currentRecordingURL: URL?

    // MARK: - Audio Settings

    /// High-quality audio settings optimized for speech
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVEncoderBitRateKey: 128000
    ]

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Permission Handling

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Check current microphone permission status
    func checkPermission() -> Bool {
        switch audioSession.recordPermission {
        case .granted:
            return true
        case .denied, .undetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Recording Control

    /// Start a new recording session
    /// - Parameter filename: Custom filename for the recording (optional)
    /// - Returns: URL of the recording file
    @discardableResult
    func startRecording(filename: String? = nil) async throws -> URL {
        // Check permission
        guard checkPermission() else {
            let granted = await requestPermission()
            guard granted else {
                throw AudioRecorderError.permissionDenied
            }
        }

        // Configure audio session
        try configureAudioSession()

        // Generate file URL
        let fileURL = generateFileURL(filename: filename)
        currentRecordingURL = fileURL

        // Create and configure audio recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            // Start recording
            guard audioRecorder?.record() == true else {
                throw AudioRecorderError.recordingFailed("Failed to start recording")
            }

            isRecording = true
            currentTime = 0
            startMonitoring()

            return fileURL
        } catch {
            throw AudioRecorderError.recordingFailed(error.localizedDescription)
        }
    }

    /// Stop the current recording session
    /// - Returns: URL of the recorded file
    func stopRecording() throws -> URL {
        guard let recorder = audioRecorder, isRecording else {
            throw AudioRecorderError.noActiveRecording
        }

        recorder.stop()
        stopMonitoring()
        deactivateAudioSession()

        isRecording = false

        guard let url = currentRecordingURL else {
            throw AudioRecorderError.fileNotFound
        }

        return url
    }

    /// Pause the current recording
    func pauseRecording() {
        audioRecorder?.pause()
    }

    /// Resume a paused recording
    func resumeRecording() {
        audioRecorder?.record()
    }

    /// Cancel the current recording and delete the file
    func cancelRecording() throws {
        guard let recorder = audioRecorder else {
            throw AudioRecorderError.noActiveRecording
        }

        recorder.stop()
        stopMonitoring()
        deactivateAudioSession()

        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        isRecording = false
        currentRecordingURL = nil
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
    }

    private func deactivateAudioSession() {
        try? audioSession.setActive(false)
    }

    private func generateFileURL(filename: String?) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = filename ?? "recording_\(Date().timeIntervalSince1970).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }

    private func startMonitoring() {
        // Monitor audio levels
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }

        // Update recording time
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder else { return }
                self.currentTime = recorder.currentTime
            }
        }
    }

    private func stopMonitoring() {
        levelTimer?.invalidate()
        timeTimer?.invalidate()
        levelTimer = nil
        timeTimer = nil
    }

    private func updateMeters() {
        audioRecorder?.updateMeters()
        let averagePower = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize power level to 0-1 range (dB range is typically -160 to 0)
        let normalizedLevel = pow(10, averagePower / 20)
        audioLevel = normalizedLevel
    }

    // MARK: - File Management

    /// Get the size of a recording file
    func getFileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return 0
        }
        return attributes[.size] as? Int64 ?? 0
    }

    /// Delete a recording file
    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = .recordingFailed("Recording did not finish successfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .recordingFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Formatted Strings

extension AudioRecorder {
    /// Format time interval as MM:SS
    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedCurrentTime: String {
        formattedTime(currentTime)
    }
}

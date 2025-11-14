//
//  WhisperService.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import Foundation

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case invalidAPIKey
    case fileNotFound
    case uploadFailed(String)
    case transcriptionFailed(String)
    case invalidResponse
    case fileTooLarge
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your configuration."
        case .fileNotFound:
            return "Audio file not found."
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .invalidResponse:
            return "Received invalid response from server."
        case .fileTooLarge:
            return "Audio file is too large (max 25MB)."
        case .unsupportedFormat:
            return "Unsupported audio format."
        }
    }
}

/// Response from Whisper API
struct WhisperResponse: Codable {
    let text: String
}

/// OpenAI Whisper transcription service
@MainActor
final class WhisperService: ObservableObject {
    // MARK: - Published Properties

    @Published var isTranscribing = false
    @Published var progress: Double = 0.0
    @Published var error: TranscriptionError?

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let model = "whisper-1"
    private let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Transcription

    /// Transcribe an audio file using OpenAI Whisper
    /// - Parameters:
    ///   - fileURL: URL of the audio file to transcribe
    ///   - language: Optional language code (e.g., "en", "es")
    ///   - prompt: Optional prompt to guide transcription style
    /// - Returns: Transcribed text
    func transcribe(
        fileURL: URL,
        language: String? = nil,
        prompt: String? = nil
    ) async throws -> String {
        // Validate API key
        guard !apiKey.isEmpty else {
            throw TranscriptionError.invalidAPIKey
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptionError.fileNotFound
        }

        // Check file size
        let fileSize = try getFileSize(at: fileURL)
        guard fileSize <= maxFileSize else {
            throw TranscriptionError.fileTooLarge
        }

        // Update status
        isTranscribing = true
        progress = 0.0
        defer {
            isTranscribing = false
            progress = 0.0
        }

        do {
            // Create multipart form data request
            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: baseURL)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // Build multipart body
            let body = try createMultipartBody(
                fileURL: fileURL,
                boundary: boundary,
                language: language,
                prompt: prompt
            )
            request.httpBody = body

            // Update progress
            progress = 0.3

            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Update progress
            progress = 0.8

            // Check response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TranscriptionError.transcriptionFailed(errorMessage)
            }

            // Parse response
            let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)

            // Update progress
            progress = 1.0

            return whisperResponse.text

        } catch let error as TranscriptionError {
            self.error = error
            throw error
        } catch {
            let transcriptionError = TranscriptionError.transcriptionFailed(error.localizedDescription)
            self.error = transcriptionError
            throw transcriptionError
        }
    }

    // MARK: - Multipart Form Data

    private func createMultipartBody(
        fileURL: URL,
        boundary: String,
        language: String?,
        prompt: String?
    ) throws -> Data {
        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")

        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        body.append("\r\n")

        // Add model
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")

        // Add language if provided
        if let language = language {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(language)\r\n")
        }

        // Add prompt if provided
        if let prompt = prompt {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            body.append("\(prompt)\r\n")
        }

        // Add response format
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("json\r\n")

        // Close boundary
        body.append("--\(boundary)--\r\n")

        return body
    }

    // MARK: - Helper Methods

    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    /// Estimate transcription time based on audio duration
    /// - Parameter duration: Audio duration in seconds
    /// - Returns: Estimated transcription time in seconds
    func estimateTranscriptionTime(for duration: TimeInterval) -> TimeInterval {
        // Whisper typically processes at about 10x real-time
        // So a 60-second audio takes about 6 seconds to transcribe
        return duration / 10
    }

    /// Format file size for display
    func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

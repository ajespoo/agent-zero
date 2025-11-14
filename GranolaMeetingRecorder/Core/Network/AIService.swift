//
//  AIService.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import Foundation

/// Errors that can occur during AI processing
enum AIServiceError: LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case invalidResponse
    case emptyTranscript
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid OpenAI API key."
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        case .invalidResponse:
            return "Received invalid response from AI service."
        case .emptyTranscript:
            return "Cannot summarize empty transcript."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        }
    }
}

/// OpenAI API request structure
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }

    struct Message: Codable {
        let role: String
        let content: String
    }
}

/// OpenAI API response structure
struct ChatCompletionResponse: Codable {
    let id: String
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }

        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}

/// Summary result with structured data
struct MeetingSummary {
    let summary: String
    let actionItems: [String]
    let keyPoints: [String]
    let decisions: [String]
}

/// OpenAI GPT-4 service for meeting summarization
@MainActor
final class AIService: ObservableObject {
    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var error: AIServiceError?

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini" // Cost-effective and fast for summaries

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Summarization

    /// Generate a concise summary of a meeting transcript
    /// - Parameter transcript: The full meeting transcript
    /// - Returns: A concise summary string
    func summarize(transcript: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.invalidAPIKey
        }

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.emptyTranscript
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        You are an expert at summarizing meeting transcripts. Analyze the following meeting transcript and provide a clear, concise summary.

        Format your response as follows:

        **Summary:**
        [2-3 sentence overview of the meeting]

        **Key Discussion Points:**
        • [Point 1]
        • [Point 2]
        • [Point 3]

        **Action Items:**
        • [Action item 1]
        • [Action item 2]

        **Decisions Made:**
        • [Decision 1]
        • [Decision 2]

        Transcript:
        \(transcript)
        """

        return try await sendRequest(prompt: prompt)
    }

    /// Extract action items from a transcript
    /// - Parameter transcript: The meeting transcript
    /// - Returns: Array of action items
    func extractActionItems(transcript: String) async throws -> [String] {
        let prompt = """
        Extract all action items and tasks from the following meeting transcript.
        List them as bullet points, one per line.
        Only include concrete, actionable items with clear owners or next steps.

        Transcript:
        \(transcript)
        """

        let response = try await sendRequest(prompt: prompt)
        return parseListItems(from: response)
    }

    /// Extract key decisions from a transcript
    /// - Parameter transcript: The meeting transcript
    /// - Returns: Array of decisions
    func extractDecisions(transcript: String) async throws -> [String] {
        let prompt = """
        Extract all important decisions made during this meeting from the following transcript.
        List them as bullet points, one per line.
        Focus on concrete decisions that were agreed upon.

        Transcript:
        \(transcript)
        """

        let response = try await sendRequest(prompt: prompt)
        return parseListItems(from: response)
    }

    /// Generate a comprehensive structured summary
    /// - Parameter transcript: The meeting transcript
    /// - Returns: MeetingSummary with structured data
    func generateStructuredSummary(transcript: String) async throws -> MeetingSummary {
        let summary = try await summarize(transcript: transcript)

        // Parse structured data from the summary
        let lines = summary.components(separatedBy: .newlines)
        var actionItems: [String] = []
        var keyPoints: [String] = []
        var decisions: [String] = []
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("Action Items:") {
                currentSection = "actions"
            } else if trimmed.contains("Key Discussion Points:") || trimmed.contains("Key Points:") {
                currentSection = "keypoints"
            } else if trimmed.contains("Decisions Made:") || trimmed.contains("Decisions:") {
                currentSection = "decisions"
            } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                switch currentSection {
                case "actions":
                    actionItems.append(item)
                case "keypoints":
                    keyPoints.append(item)
                case "decisions":
                    decisions.append(item)
                default:
                    break
                }
            }
        }

        return MeetingSummary(
            summary: summary,
            actionItems: actionItems,
            keyPoints: keyPoints,
            decisions: decisions
        )
    }

    // MARK: - Private Methods

    private func sendRequest(prompt: String) async throws -> String {
        // Prepare request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create request body
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: "You are a helpful assistant that specializes in analyzing and summarizing meeting transcripts."),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.3, // Lower temperature for more focused, consistent summaries
            maxTokens: 1500
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                throw AIServiceError.rateLimitExceeded
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.requestFailed("Status \(httpResponse.statusCode): \(errorMessage)")
            }

            // Parse response
            let completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

            guard let content = completionResponse.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }

            return content

        } catch let error as AIServiceError {
            self.error = error
            throw error
        } catch {
            let serviceError = AIServiceError.requestFailed(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }

    private func parseListItems(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        return lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("•") || $0.hasPrefix("-") || $0.hasPrefix("*") }
            .map { line in
                let item = line.dropFirst().trimmingCharacters(in: .whitespaces)
                return item
            }
            .filter { !$0.isEmpty }
    }

    // MARK: - Token Estimation

    /// Estimate token count for text (rough approximation)
    /// - Parameter text: The text to estimate
    /// - Returns: Approximate token count
    func estimateTokenCount(for text: String) -> Int {
        // Rough estimate: 1 token ≈ 4 characters for English
        return text.count / 4
    }

    /// Check if transcript is within token limits
    /// - Parameter transcript: The transcript to check
    /// - Returns: True if within limits
    func isWithinTokenLimit(transcript: String) -> Bool {
        let estimatedTokens = estimateTokenCount(for: transcript)
        // GPT-4o-mini has 128k context window, but we'll be conservative
        return estimatedTokens < 100_000
    }
}

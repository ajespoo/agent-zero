//
//  RecordingView.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioRecorder: AudioRecorder
    @EnvironmentObject private var whisperService: WhisperService
    @EnvironmentObject private var aiService: AIService

    // MARK: - Properties

    let meetingTitle: String
    let calendarEventID: String?
    let participants: [String]

    // MARK: - State

    @State private var currentMeeting: Meeting?
    @State private var showingCancelAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.red.opacity(0.1), .orange.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    // Recording Indicator
                    recordingIndicator

                    // Audio Visualization
                    AudioWaveformView(audioLevel: audioRecorder.audioLevel)
                        .frame(height: 200)
                        .padding(.horizontal)

                    // Timer
                    timerView

                    Spacer()

                    // Controls
                    controlButtons
                }
                .padding()
            }
            .navigationTitle(meetingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive) {
                        showingCancelAlert = true
                    }
                }
            }
            .alert("Cancel Recording?", isPresented: $showingCancelAlert) {
                Button("Keep Recording", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    cancelRecording()
                }
            } message: {
                Text("Are you sure you want to discard this recording?")
            }
            .alert("Recording Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(errorMessage)
            }
            .task {
                await startRecording()
            }
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(.red.opacity(0.3), lineWidth: 8)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                )

            Text("Recording")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
    }

    // MARK: - Timer View

    private var timerView: some View {
        VStack(spacing: 8) {
            Text(audioRecorder.formattedCurrentTime)
                .font(.system(size: 56, weight: .thin, design: .monospaced))
                .foregroundStyle(.primary)

            Text("Meeting Duration")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack(spacing: 24) {
            // Stop Recording Button
            Button(action: stopRecording) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop & Save Recording")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)

            // Info Text
            Text("Your meeting will be automatically transcribed and summarized after recording")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Methods

    private func startRecording() async {
        do {
            // Request microphone permission if needed
            guard audioRecorder.checkPermission() || await audioRecorder.requestPermission() else {
                errorMessage = "Microphone permission is required to record meetings."
                showingError = true
                return
            }

            // Create meeting record
            let meeting = Meeting(
                title: meetingTitle,
                calendarEventID: calendarEventID,
                date: Date(),
                status: .recording,
                participants: participants
            )

            modelContext.insert(meeting)
            currentMeeting = meeting

            // Start recording
            let audioURL = try await audioRecorder.startRecording(
                filename: "meeting_\(meeting.id.uuidString).m4a"
            )

            // Update meeting with audio file info
            meeting.audioFilePath = audioURL.lastPathComponent

        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func stopRecording() {
        guard let meeting = currentMeeting else { return }

        do {
            // Stop recording
            let audioURL = try audioRecorder.stopRecording()

            // Update meeting details
            meeting.duration = audioRecorder.currentTime
            meeting.audioFileSize = audioRecorder.getFileSize(at: audioURL)
            meeting.status = .processing
            meeting.markAsUpdated()

            // Save context
            try modelContext.save()

            // Start background processing
            Task {
                await processRecording(meeting: meeting, audioURL: audioURL)
            }

            // Dismiss view
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func cancelRecording() {
        do {
            try audioRecorder.cancelRecording()

            if let meeting = currentMeeting {
                modelContext.delete(meeting)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func processRecording(meeting: Meeting, audioURL: URL) async {
        // Transcribe audio
        meeting.status = .transcribing
        meeting.markAsUpdated()

        do {
            let transcript = try await whisperService.transcribe(fileURL: audioURL)
            meeting.transcript = transcript
            meeting.isTranscribed = true
            meeting.transcriptionProgress = 1.0
            meeting.markAsUpdated()

            // Generate AI summary
            meeting.status = .summarizing
            meeting.markAsUpdated()

            let structuredSummary = try await aiService.generateStructuredSummary(transcript: transcript)
            meeting.summary = structuredSummary.summary
            meeting.actionItems = structuredSummary.actionItems
            meeting.status = .completed
            meeting.isSummarized = true
            meeting.markAsUpdated()

            try modelContext.save()

        } catch {
            meeting.status = .failed
            meeting.notes = "Error: \(error.localizedDescription)"
            meeting.markAsUpdated()
            try? modelContext.save()
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let audioLevel: Float

    @State private var animatedLevels: [CGFloat] = Array(repeating: 0.1, count: 50)

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<animatedLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth(for: geometry.size.width))
                        .frame(height: animatedLevels[index] * geometry.size.height)
                        .animation(
                            .easeInOut(duration: 0.1),
                            value: animatedLevels[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            updateWaveform(with: newValue)
        }
    }

    private func barWidth(for totalWidth: CGFloat) -> CGFloat {
        let spacing: CGFloat = 4
        let totalSpacing = spacing * CGFloat(animatedLevels.count - 1)
        return (totalWidth - totalSpacing) / CGFloat(animatedLevels.count)
    }

    private func updateWaveform(with level: Float) {
        // Shift existing levels
        animatedLevels.removeFirst()

        // Add new level with some randomization for visual effect
        let normalizedLevel = CGFloat(level)
        let randomVariation = CGFloat.random(in: 0.8...1.2)
        let newLevel = min(max(normalizedLevel * randomVariation, 0.05), 1.0)

        animatedLevels.append(newLevel)
    }
}

// MARK: - New Meeting View

struct NewMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var meetingTitle = ""
    @State private var selectedParticipants: [String] = []
    @State private var newParticipant = ""
    @State private var showingRecording = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Meeting Details") {
                    TextField("Meeting Title", text: $meetingTitle)

                    DatePicker("Date & Time", selection: .constant(Date()))
                        .disabled(true)
                }

                Section("Participants") {
                    ForEach(selectedParticipants, id: \.self) { participant in
                        Text(participant)
                    }
                    .onDelete { indexSet in
                        selectedParticipants.remove(atOffsets: indexSet)
                    }

                    HStack {
                        TextField("Add participant", text: $newParticipant)
                        Button("Add") {
                            if !newParticipant.isEmpty {
                                selectedParticipants.append(newParticipant)
                                newParticipant = ""
                            }
                        }
                        .disabled(newParticipant.isEmpty)
                    }
                }
            }
            .navigationTitle("New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Start Recording") {
                        startRecording()
                    }
                    .disabled(meetingTitle.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showingRecording) {
                RecordingView(
                    meetingTitle: meetingTitle.isEmpty ? "Untitled Meeting" : meetingTitle,
                    calendarEventID: nil,
                    participants: selectedParticipants
                )
            }
        }
    }

    private func startRecording() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingRecording = true
        }
    }
}

// MARK: - Preview

#Preview("Recording") {
    RecordingView(
        meetingTitle: "Product Planning",
        calendarEventID: nil,
        participants: ["Alice", "Bob"]
    )
    .environmentObject(AudioRecorder())
    .environmentObject(WhisperService(apiKey: "preview"))
    .environmentObject(AIService(apiKey: "preview"))
    .modelContainer(for: Meeting.self, inMemory: true)
}

#Preview("New Meeting") {
    NewMeetingView()
        .modelContainer(for: Meeting.self, inMemory: true)
}

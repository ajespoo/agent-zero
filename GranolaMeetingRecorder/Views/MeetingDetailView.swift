//
//  MeetingDetailView.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import SwiftUI
import SwiftData
import AVFoundation

struct MeetingDetailView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    @Bindable var meeting: Meeting

    // MARK: - State

    @State private var selectedTab: DetailTab = .summary
    @State private var showingShareSheet = false
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Meeting Header
                meetingHeader

                // Tab Picker
                tabPicker

                // Content based on selected tab
                tabContent
            }
            .padding()
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(meeting: meeting)
        }
    }

    // MARK: - Meeting Header

    private var meetingHeader: some View {
        VStack(spacing: 16) {
            // Status Badge
            if meeting.status != .completed {
                StatusBadge(status: meeting.status)
            }

            // Meeting Info Cards
            HStack(spacing: 12) {
                InfoCard(
                    icon: "clock",
                    title: "Duration",
                    value: meeting.formattedDuration
                )

                InfoCard(
                    icon: "calendar",
                    title: "Date",
                    value: formattedDate
                )

                if !meeting.participants.isEmpty {
                    InfoCard(
                        icon: "person.2",
                        title: "Attendees",
                        value: "\(meeting.participants.count)"
                    )
                }
            }

            // Audio Player
            if meeting.audioFileURL != nil {
                audioPlayerView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Audio Player

    private var audioPlayerView: some View {
        HStack {
            Button(action: toggleAudioPlayback) {
                Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Recording")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(meeting.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .summary:
            summaryView
        case .transcript:
            transcriptView
        case .details:
            detailsView
        }
    }

    // MARK: - Summary View

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if meeting.isSummarized, let summary = meeting.summary {
                // AI Summary
                SectionCard(title: "AI Summary", icon: "sparkles") {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                // Action Items
                if !meeting.actionItems.isEmpty {
                    SectionCard(title: "Action Items", icon: "checklist") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(meeting.actionItems, id: \.self) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .padding(.top, 4)

                                    Text(item)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
            } else if meeting.status == .summarizing {
                ProgressCard(message: "Generating AI summary...")
            } else if meeting.status == .transcribing || meeting.status == .processing {
                ProgressCard(message: "Processing recording...")
            } else {
                EmptyContentCard(
                    icon: "doc.text",
                    message: "Summary not available yet"
                )
            }
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if meeting.isTranscribed, let transcript = meeting.transcript {
                SectionCard(title: "Full Transcript", icon: "doc.text") {
                    Text(transcript)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            } else if meeting.status == .transcribing {
                ProgressCard(message: "Transcribing audio...")
            } else if meeting.status == .processing {
                ProgressCard(message: "Processing audio...")
            } else {
                EmptyContentCard(
                    icon: "waveform",
                    message: "Transcript not available yet"
                )
            }
        }
    }

    // MARK: - Details View

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Participants
            if !meeting.participants.isEmpty {
                SectionCard(title: "Participants", icon: "person.2") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(meeting.participants, id: \.self) { participant in
                            Text(participant)
                                .font(.body)
                        }
                    }
                }
            }

            // Notes
            if let notes = meeting.notes {
                SectionCard(title: "Notes", icon: "note.text") {
                    Text(notes)
                        .font(.body)
                }
            }

            // Metadata
            SectionCard(title: "Metadata", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    MetadataRow(label: "Created", value: formattedCreatedDate)
                    MetadataRow(label: "Last Updated", value: formattedUpdatedDate)
                    MetadataRow(label: "Status", value: meeting.status.rawValue.capitalized)
                    if let audioFilePath = meeting.audioFilePath {
                        MetadataRow(label: "Audio File", value: audioFilePath)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { showingShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button(action: exportTranscript) {
                    Label("Export Transcript", systemImage: "doc.text")
                }

                Divider()

                Button(role: .destructive, action: deleteMeeting) {
                    Label("Delete Meeting", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meeting.date)
    }

    private var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meeting.createdAt)
    }

    private var formattedUpdatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meeting.updatedAt)
    }

    // MARK: - Actions

    private func toggleAudioPlayback() {
        guard let audioURL = meeting.audioFileURL else { return }

        if isPlayingAudio {
            audioPlayer?.pause()
            isPlayingAudio = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.play()
                isPlayingAudio = true
            } catch {
                print("Failed to play audio: \(error)")
            }
        }
    }

    private func exportTranscript() {
        // Export functionality would be implemented here
        print("Exporting transcript...")
    }

    private func deleteMeeting() {
        if let audioURL = meeting.audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        modelContext.delete(meeting)
    }
}

// MARK: - Detail Tab

enum DetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
    case details = "Details"
}

// MARK: - Supporting Views

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ProgressCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct EmptyContentCard: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.gray)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct ShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let meeting: Meeting

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: shareAsText) {
                        Label("Share as Text", systemImage: "doc.text")
                    }

                    Button(action: shareAudio) {
                        Label("Share Audio", systemImage: "waveform")
                    }
                }
            }
            .navigationTitle("Share Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareAsText() {
        // Share implementation
        print("Sharing as text...")
    }

    private func shareAudio() {
        // Share implementation
        print("Sharing audio...")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingDetailView(meeting: .sample)
    }
    .environmentObject(AudioRecorder())
    .modelContainer(for: Meeting.self, inMemory: true)
}

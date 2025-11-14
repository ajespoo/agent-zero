//
//  MeetingsListView.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import SwiftUI
import SwiftData

struct MeetingsListView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedFilter: MeetingFilter = .all
    @State private var showingNewMeeting = false
    @State private var selectedMeeting: Meeting?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    emptyStateView
                } else {
                    meetingsList
                }
            }
            .navigationTitle("My Meetings")
            .navigationDestination(item: $selectedMeeting) { meeting in
                MeetingDetailView(meeting: meeting)
            }
            .searchable(text: $searchText, prompt: "Search meetings")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingNewMeeting) {
                NewMeetingView()
            }
        }
    }

    // MARK: - Meetings List

    private var meetingsList: some View {
        List {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(MeetingFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Meetings grouped by date
            ForEach(groupedMeetings.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(dateFormatter.string(from: date))) {
                    ForEach(groupedMeetings[date] ?? []) { meeting in
                        MeetingRow(meeting: meeting)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMeeting(meeting)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    shareMeeting(meeting)
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            // Refresh logic if needed
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(.gray)

            Text("No Meetings Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record your first meeting by tapping the + button")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showingNewMeeting = true }) {
                Label("Record New Meeting", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showingNewMeeting = true }) {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredMeetings: [Meeting] {
        var filtered = meetings

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { meeting in
                meeting.title.localizedCaseInsensitiveContains(searchText) ||
                meeting.participants.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (meeting.transcript?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        case .processing:
            filtered = filtered.filter {
                $0.status == .processing ||
                $0.status == .transcribing ||
                $0.status == .summarizing
            }
        case .recent:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            filtered = filtered.filter { $0.date >= weekAgo }
        }

        return filtered
    }

    private var groupedMeetings: [Date: [Meeting]] {
        Dictionary(grouping: filteredMeetings) { meeting in
            Calendar.current.startOfDay(for: meeting.date)
        }
    }

    // MARK: - Date Formatter

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        // Show relative dates for recent meetings
        if Calendar.current.isDateInToday(Date()) {
            formatter.doesRelativeDateFormatting = true
        }

        return formatter
    }

    // MARK: - Actions

    private func deleteMeeting(_ meeting: Meeting) {
        withAnimation {
            // Delete audio file if it exists
            if let audioURL = meeting.audioFileURL {
                try? FileManager.default.removeItem(at: audioURL)
            }

            // Delete from database
            modelContext.delete(meeting)
        }
    }

    private func shareMeeting(_ meeting: Meeting) {
        // Share functionality - would typically present a share sheet
        // This is a placeholder for the actual implementation
        print("Sharing meeting: \(meeting.title)")
    }
}

// MARK: - Meeting Filter

enum MeetingFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case processing = "Processing"
    case recent = "Recent"
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.15))
                .clipShape(Circle())

            // Meeting Info
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(timeString, systemImage: "clock")
                    if !meeting.participants.isEmpty {
                        Label("\(meeting.participants.count)", systemImage: "person.2")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if meeting.status != .completed {
                    StatusBadge(status: meeting.status)
                }
            }

            Spacer()

            // Duration
            VStack(alignment: .trailing, spacing: 4) {
                Text(meeting.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if meeting.isTranscribed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title3)
            .foregroundStyle(statusColor)
    }

    private var statusIconName: String {
        switch meeting.status {
        case .recording:
            return "record.circle"
        case .processing, .transcribing, .summarizing:
            return "waveform.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "mic.circle"
        }
    }

    private var statusColor: Color {
        switch meeting.status {
        case .recording:
            return .red
        case .processing, .transcribing, .summarizing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .orange
        default:
            return .gray
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: meeting.date)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: RecordingStatus

    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .transcribing:
            return "Transcribing"
        case .summarizing:
            return "Summarizing"
        default:
            return status.rawValue.capitalized
        }
    }

    private var statusColor: Color {
        switch status {
        case .recording:
            return .red
        case .processing, .transcribing, .summarizing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingsListView()
    }
    .environmentObject(AudioRecorder())
    .modelContainer(for: Meeting.self, inMemory: true)
}

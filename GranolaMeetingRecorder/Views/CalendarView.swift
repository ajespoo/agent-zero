//
//  CalendarView.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import SwiftUI

struct CalendarView: View {
    // MARK: - Environment Objects

    @EnvironmentObject private var calendarManager: CalendarManager

    // MARK: - State

    @State private var events: [CalendarEvent] = []
    @State private var isLoading = false
    @State private var error: CalendarError?
    @State private var selectedEvent: CalendarEvent?
    @State private var showingRecordSheet = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !calendarManager.isAuthorized {
                    permissionView
                } else if isLoading {
                    loadingView
                } else if events.isEmpty {
                    emptyStateView
                } else {
                    eventsList
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refreshEvents) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadEvents()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
            }
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Calendar Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Grant calendar access to view your upcoming meetings and quickly start recordings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: requestPermission) {
                Label("Grant Access", systemImage: "calendar")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading events...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 80))
                .foregroundStyle(.gray)

            Text("No Upcoming Events")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You don't have any upcoming calendar events in the next 7 days.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Events List

    private var eventsList: some View {
        List {
            // Happening Now Section
            if !currentEvents.isEmpty {
                Section("Happening Now") {
                    ForEach(currentEvents) { event in
                        EventRow(event: event, isLive: true)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }

            // Upcoming Events Section
            if !upcomingEvents.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingEvents) { event in
                        EventRow(event: event)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }

            // Past Events (Today)
            if !pastTodayEvents.isEmpty {
                Section("Earlier Today") {
                    ForEach(pastTodayEvents) { event in
                        EventRow(event: event, isPast: true)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadEvents()
        }
    }

    // MARK: - Computed Properties

    private var currentEvents: [CalendarEvent] {
        events.filter { $0.isHappening }
    }

    private var upcomingEvents: [CalendarEvent] {
        events.filter { $0.isUpcoming }
    }

    private var pastTodayEvents: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            event.isPast && calendar.isDateInToday(event.startDate)
        }
    }

    // MARK: - Methods

    private func requestPermission() {
        Task {
            _ = await calendarManager.requestAccess()
            await loadEvents()
        }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            events = try await calendarManager.fetchUpcomingEvents(days: 7)
        } catch let error as CalendarError {
            self.error = error
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
        }
    }

    private func refreshEvents() {
        Task {
            await loadEvents()
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    var isLive: Bool = false
    var isPast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: event.startDate))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isLive {
                    Text("Now")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 60, alignment: .leading)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let location = event.location {
                        Label(location, systemImage: "location")
                            .lineLimit(1)
                    }
                    Label(event.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !event.attendees.isEmpty {
                    Label("\(event.attendees.count) attendees", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Live indicator or chevron
            if isLive {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(isPast ? 0.6 : 1.0)
        .padding(.vertical, 4)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioRecorder: AudioRecorder

    let event: CalendarEvent

    @State private var showingRecording = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Time", systemImage: "clock")
                            .font(.headline)
                        Text(event.formattedTimeRange)
                            .font(.body)
                    }

                    Divider()

                    // Location Section
                    if let location = event.location {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Location", systemImage: "location")
                                .font(.headline)
                            Text(location)
                                .font(.body)
                        }
                        Divider()
                    }

                    // Attendees Section
                    if !event.attendees.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Attendees", systemImage: "person.2")
                                .font(.headline)
                            ForEach(event.attendees, id: \.self) { attendee in
                                Text(attendee)
                                    .font(.body)
                            }
                        }
                        Divider()
                    }

                    // Notes Section
                    if let notes = event.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                        }
                    }

                    // Record Button
                    Button(action: startRecording) {
                        Label("Record This Meeting", systemImage: "record.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                }
                .padding()
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingRecording) {
                RecordingView(
                    meetingTitle: event.title,
                    calendarEventID: event.id,
                    participants: event.attendees
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

// MARK: - Settings View Placeholder

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("API Configuration") {
                    HStack {
                        Text("API Key Status")
                        Spacer()
                        if Config.isAPIKeyConfigured() {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Set", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Config.App.version)
                    LabeledContent("App Name", value: Config.App.name)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environmentObject(CalendarManager())
        .environmentObject(AudioRecorder())
}

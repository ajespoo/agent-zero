//
//  CalendarEvent.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import Foundation
import EventKit

/// Represents a calendar event that can be recorded
struct CalendarEvent: Identifiable, Hashable {
    // MARK: - Properties

    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let attendees: [String]
    let calendarTitle: String
    let isAllDay: Bool

    // MARK: - Computed Properties

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var isHappening: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var isUpcoming: Bool {
        Date() < startDate
    }

    var isPast: Bool {
        Date() > endDate
    }

    // MARK: - Initialization

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        attendees: [String] = [],
        calendarTitle: String = "Calendar",
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.calendarTitle = calendarTitle
        self.isAllDay = isAllDay
    }

    /// Initialize from an EventKit EKEvent
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Meeting"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.attendees = ekEvent.attendees?.compactMap { $0.name } ?? []
        self.calendarTitle = ekEvent.calendar.title
        self.isAllDay = ekEvent.isAllDay
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension CalendarEvent {
    static var sample: CalendarEvent {
        CalendarEvent(
            id: "sample-event-1",
            title: "Team Sync",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            location: "Conference Room A",
            notes: "Weekly team synchronization meeting",
            attendees: ["Alice", "Bob", "Carol"],
            calendarTitle: "Work"
        )
    }

    static var samples: [CalendarEvent] {
        [
            CalendarEvent(
                id: "sample-1",
                title: "Product Review",
                startDate: Date().addingTimeInterval(3600),
                endDate: Date().addingTimeInterval(5400),
                location: "Zoom",
                attendees: ["Product Team"],
                calendarTitle: "Work"
            ),
            CalendarEvent(
                id: "sample-2",
                title: "1:1 with Manager",
                startDate: Date().addingTimeInterval(7200),
                endDate: Date().addingTimeInterval(9000),
                attendees: ["Sarah Johnson"],
                calendarTitle: "Work"
            ),
            CalendarEvent(
                id: "sample-3",
                title: "Client Call",
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(-1800),
                location: "Phone",
                attendees: ["Client XYZ"],
                calendarTitle: "Work"
            )
        ]
    }
}

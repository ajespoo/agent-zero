//
//  CalendarManager.swift
//  GranolaMeetingRecorder
//
//  Created by Granola on 2025-11-14.
//

import EventKit
import Foundation
import Combine

/// Errors that can occur during calendar operations
enum CalendarError: LocalizedError {
    case permissionDenied
    case eventNotFound
    case accessRestricted
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access is required to view your meetings."
        case .eventNotFound:
            return "Calendar event not found."
        case .accessRestricted:
            return "Calendar access is restricted."
        case .fetchFailed(let reason):
            return "Failed to fetch events: \(reason)"
        }
    }
}

/// Manages calendar access and event retrieval using EventKit
@MainActor
final class CalendarManager: ObservableObject {
    // MARK: - Published Properties

    @Published var events: [CalendarEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var error: CalendarError?

    // MARK: - Private Properties

    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request calendar access permission
    func requestAccess() async -> Bool {
        do {
            #if swift(>=5.9)
            // iOS 17+ API
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return granted
            #else
            // iOS 16 and below
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        self.updateAuthorizationStatus()
                        continuation.resume(returning: granted)
                    }
                }
            }
            #endif
        } catch {
            await MainActor.run {
                self.error = .fetchFailed(error.localizedDescription)
            }
            return false
        }
    }

    /// Update the current authorization status
    private func updateAuthorizationStatus() {
        #if swift(>=5.9)
        // iOS 17+
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        #else
        // iOS 16 and below
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        #endif
    }

    /// Check if calendar access is authorized
    var isAuthorized: Bool {
        #if swift(>=5.9)
        return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        #else
        return authorizationStatus == .authorized
        #endif
    }

    // MARK: - Fetch Events

    /// Fetch events for a specified date range
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Array of CalendarEvent objects
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard isAuthorized else {
            let granted = await requestAccess()
            guard granted else {
                throw CalendarError.permissionDenied
            }
        }

        // Create predicate for date range
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        // Fetch events
        let ekEvents = eventStore.events(matching: predicate)

        // Convert to CalendarEvent objects
        let calendarEvents = ekEvents.map { CalendarEvent(from: $0) }

        // Update published property
        await MainActor.run {
            self.events = calendarEvents
        }

        return calendarEvents
    }

    /// Fetch today's events
    func fetchTodaysEvents() async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await fetchEvents(from: startOfDay, to: endOfDay)
    }

    /// Fetch this week's events
    func fetchThisWeeksEvents() async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!

        return try await fetchEvents(from: startOfWeek, to: endOfWeek)
    }

    /// Fetch upcoming events (next 7 days)
    func fetchUpcomingEvents(days: Int = 7) async throws -> [CalendarEvent] {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: now)!

        return try await fetchEvents(from: now, to: endDate)
    }

    /// Fetch a specific event by ID
    func fetchEvent(withIdentifier identifier: String) -> CalendarEvent? {
        guard let ekEvent = eventStore.event(withIdentifier: identifier) else {
            return nil
        }
        return CalendarEvent(from: ekEvent)
    }

    // MARK: - Event Filtering

    /// Filter events happening now
    func currentEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { $0.isHappening }
    }

    /// Filter upcoming events
    func upcomingEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { $0.isUpcoming }
    }

    /// Filter past events
    func pastEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { $0.isPast }
    }

    // MARK: - Calendar Management

    /// Get all available calendars
    func getCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    /// Get calendar names
    func getCalendarNames() -> [String] {
        getCalendars().map { $0.title }
    }

    // MARK: - Refresh

    /// Refresh calendar data
    func refresh() async {
        do {
            _ = try await fetchUpcomingEvents()
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Helper Extensions

extension CalendarManager {
    /// Get events grouped by date
    func eventsByDate(from events: [CalendarEvent]) -> [Date: [CalendarEvent]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event -> Date in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped
    }

    /// Get events sorted by start date
    func sortedEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        events.sorted { $0.startDate < $1.startDate }
    }
}

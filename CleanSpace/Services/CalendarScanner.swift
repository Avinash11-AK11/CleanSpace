import Foundation
import EventKit
import Combine

struct CleanableCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let isAllDay: Bool
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = isAllDay ? .none : .short
        return formatter.string(from: startDate)
    }
}

enum CalendarFilterPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "Older than 30 Days"
    case threeMonths = "Older than 90 Days"
    case oneYear = "Older than 1 Year"
    case allPast = "All Past Events"
    
    var id: String { rawValue }
    
    var shortTitle: String {
        switch self {
        case .oneMonth: return "> 30 Days"
        case .threeMonths: return "> 90 Days"
        case .oneYear: return "> 1 Year"
        case .allPast: return "All Past"
        }
    }
    
    var cutoffDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .threeMonths:
            return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allPast:
            return now
        }
    }
}

@MainActor
class CalendarScanner: ObservableObject {
    static let shared = CalendarScanner()
    
    private let eventStore = EKEventStore()
    @Published var events: [CleanableCalendarEvent] = []
    @Published var isScanning = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        do {
            var granted = false
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            checkAuthorization()
            return granted
        } catch {
            print("CleanSpace: Calendar access error: \(error)")
            return false
        }
    }
    
    func fetchPastEvents(period: CalendarFilterPeriod = .oneMonth) async {
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            return
        }
        
        isScanning = true
        
        let cutoff = period.cutoffDate
        let pastStartDate = Calendar.current.date(byAdding: .year, value: -4, to: cutoff) ?? cutoff
        let calendars = eventStore.calendars(for: .event)
        
        let predicate = eventStore.predicateForEvents(withStart: pastStartDate, end: cutoff, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        let mapped = ekEvents.map { event in
            CleanableCalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarTitle: event.calendar.title,
                isAllDay: event.isAllDay
            )
        }.sorted { $0.startDate > $1.startDate }
        
        self.events = mapped
        self.isScanning = false
    }
    
    func deleteEvents(withIds ids: Set<String>) async -> Int {
        var deletedCount = 0
        for id in ids {
            if let event = eventStore.event(withIdentifier: id) {
                do {
                    try eventStore.remove(event, span: .thisEvent, commit: false)
                    deletedCount += 1
                } catch {
                    print("CleanSpace: Failed to remove event \(id): \(error)")
                }
            }
        }
        
        do {
            try eventStore.commit()
            self.events.removeAll { ids.contains($0.id) }
        } catch {
            print("CleanSpace: Failed to commit event removals: \(error)")
        }
        
        return deletedCount
    }
}

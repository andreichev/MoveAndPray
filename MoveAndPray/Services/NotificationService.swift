import Foundation
import UserNotifications

enum ReminderAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

protocol NotificationServicing: AnyObject {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async -> ReminderAuthorizationStatus
    func replaceDailyReminders(
        preferences: ReminderPreferences,
        records: [HabitDayRecord]
    ) async throws
}

final class NotificationService: NotificationServicing {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "moveandpray.daily."

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        let settings = await center.notificationSettings()
        return map(settings.authorizationStatus)
    }

    func requestAuthorization() async -> ReminderAuthorizationStatus {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return .denied
        }
        return await authorizationStatus()
    }

    func replaceDailyReminders(
        preferences: ReminderPreferences,
        records: [HabitDayRecord]
    ) async throws {
        try Task.checkCancellation()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        try Task.checkCancellation()
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard preferences.isEnabled else { return }

        let calendar = AppCalendar.current
        let now = Date()
        let recordsByKey = Dictionary(uniqueKeysWithValues: records.map { (DayKey.make(for: $0.date), $0) })

        for dayOffset in 0..<32 {
            try Task.checkCancellation()
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            var triggerDate = calendar.dateComponents([.year, .month, .day], from: date)
            triggerDate.calendar = calendar
            triggerDate.hour = preferences.hour
            triggerDate.minute = preferences.minute
            triggerDate.second = 0
            triggerDate.timeZone = .autoupdatingCurrent
            guard let scheduledDate = calendar.date(from: triggerDate), scheduledDate > now else { continue }

            let record = recordsByKey[DayKey.make(for: date)]
                ?? HabitDayRecord(date: date, completedHabits: [])
            guard record.completedHabits.count < HabitKind.allCases.count else { continue }

            let content = UNMutableNotificationContent()
            content.title = L10n.text("reminder.notification.title")
            content.body = reminderBody(for: record.completedHabits)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + DayKey.make(for: date),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            try Task.checkCancellation()
        }
    }

    private func map(_ status: UNAuthorizationStatus) -> ReminderAuthorizationStatus {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    private func reminderBody(for completed: Set<HabitKind>) -> String {
        switch (completed.contains(.workout), completed.contains(.prayer)) {
        case (true, false):
            return L10n.text("reminder.notification.only_prayer")
        case (false, true):
            return L10n.text("reminder.notification.only_workout")
        default:
            return L10n.text("reminder.notification.both")
        }
    }
}

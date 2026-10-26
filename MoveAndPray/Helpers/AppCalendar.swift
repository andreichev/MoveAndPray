import Foundation

enum AppCalendar {
    static var current: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    static func startOfMonth(containing date: Date) -> Date {
        let calendar = current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func month(byAdding value: Int, to date: Date) -> Date {
        current.date(byAdding: .month, value: value, to: startOfMonth(containing: date)) ?? date
    }

    static func gridDates(forMonthContaining date: Date) -> [Date] {
        let calendar = current
        let monthStart = startOfMonth(containing: date)
        let weekday = calendar.component(.weekday, from: monthStart)
        let daysFromMonday = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else {
            return []
        }

        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }
}

enum DayKey {
    static func make(for date: Date, calendar: Calendar = AppCalendar.current) -> String {
        // Stored keys must remain stable when the user changes their preferred calendar.
        var storageCalendar = Calendar(identifier: .gregorian)
        storageCalendar.timeZone = calendar.timeZone
        let components = storageCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

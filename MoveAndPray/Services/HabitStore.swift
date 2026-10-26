import Foundation

enum HabitKind: String, CaseIterable, Codable, Hashable {
    case workout
    case prayer
}

struct HabitDayRecord: Equatable {
    let date: Date
    let completedHabits: Set<HabitKind>

    func isCompleted(_ habit: HabitKind) -> Bool {
        completedHabits.contains(habit)
    }
}

struct ReminderPreferences: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    static let defaultValue = ReminderPreferences(isEnabled: false, hour: 20, minute: 0)
}

protocol HabitStoring: AnyObject {
    func record(for date: Date) -> HabitDayRecord
    func records(for dates: [Date]) -> [HabitDayRecord]
    @discardableResult func toggle(_ habit: HabitKind, on date: Date) -> HabitDayRecord
    func currentStreak(for habit: HabitKind, asOf date: Date) -> Int
    var hasAcknowledgedPrayerGuidance: Bool { get set }
    var reminderPreferences: ReminderPreferences { get set }
}

final class HabitStore: HabitStoring {
    private enum Keys {
        static let completedHabitsByDay = "completedHabitsByDay.v1"
        static let hasAcknowledgedPrayerGuidance = "hasAcknowledgedPrayerGuidance.v1"
        static let reminderEnabled = "reminderEnabled.v1"
        static let reminderHour = "reminderHour.v1"
        static let reminderMinute = "reminderMinute.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasAcknowledgedPrayerGuidance: Bool {
        get { defaults.bool(forKey: Keys.hasAcknowledgedPrayerGuidance) }
        set { defaults.set(newValue, forKey: Keys.hasAcknowledgedPrayerGuidance) }
    }

    var reminderPreferences: ReminderPreferences {
        get {
            let hour = defaults.object(forKey: Keys.reminderHour) == nil
                ? ReminderPreferences.defaultValue.hour
                : defaults.integer(forKey: Keys.reminderHour)
            let minute = defaults.object(forKey: Keys.reminderMinute) == nil
                ? ReminderPreferences.defaultValue.minute
                : defaults.integer(forKey: Keys.reminderMinute)
            return ReminderPreferences(
                isEnabled: defaults.bool(forKey: Keys.reminderEnabled),
                hour: min(max(hour, 0), 23),
                minute: min(max(minute, 0), 59)
            )
        }
        set {
            defaults.set(newValue.isEnabled, forKey: Keys.reminderEnabled)
            defaults.set(newValue.hour, forKey: Keys.reminderHour)
            defaults.set(newValue.minute, forKey: Keys.reminderMinute)
        }
    }

    func record(for date: Date) -> HabitDayRecord {
        let rawValues = completionMap()[DayKey.make(for: date)] ?? []
        let habits = Set(rawValues.compactMap(HabitKind.init(rawValue:)))
        return HabitDayRecord(date: AppCalendar.current.startOfDay(for: date), completedHabits: habits)
    }

    func records(for dates: [Date]) -> [HabitDayRecord] {
        let map = completionMap()
        let calendar = AppCalendar.current
        return dates.map { date in
            let habits = Set((map[DayKey.make(for: date)] ?? []).compactMap(HabitKind.init(rawValue:)))
            return HabitDayRecord(date: calendar.startOfDay(for: date), completedHabits: habits)
        }
    }

    @discardableResult
    func toggle(_ habit: HabitKind, on date: Date) -> HabitDayRecord {
        var map = completionMap()
        let key = DayKey.make(for: date)
        var values = Set(map[key] ?? [])
        if values.contains(habit.rawValue) {
            values.remove(habit.rawValue)
        } else {
            values.insert(habit.rawValue)
        }

        if values.isEmpty {
            map.removeValue(forKey: key)
        } else {
            map[key] = values.sorted()
        }
        defaults.set(map, forKey: Keys.completedHabitsByDay)
        return record(for: date)
    }

    func currentStreak(for habit: HabitKind, asOf date: Date) -> Int {
        let calendar = AppCalendar.current
        var cursor = calendar.startOfDay(for: date)
        if !record(for: cursor).isCompleted(habit) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while record(for: cursor).isCompleted(habit) {
            streak += 1
            guard streak < 36_500,
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    private func completionMap() -> [String: [String]] {
        defaults.dictionary(forKey: Keys.completedHabitsByDay) as? [String: [String]] ?? [:]
    }
}

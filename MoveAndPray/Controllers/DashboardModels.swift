import Foundation

enum HabitCompletionVisualState: Equatable {
    case completed
    case missed
    case pending
    case future
}

struct HabitDisplayModel: Equatable {
    let kind: HabitKind
    let title: String
    let detail: String
    let actionTitle: String
    let streakText: String
    let symbolName: String
    let isCompleted: Bool
}

struct CalendarDayDisplayModel: Equatable {
    let dayText: String
    let accessibilityText: String
    let workoutState: HabitCompletionVisualState
    let prayerState: HabitCompletionVisualState
    let isInDisplayedMonth: Bool
    let isToday: Bool
}

struct DashboardDisplayModel: Equatable {
    let dateText: String
    let progressText: String
    let motivationText: String
    let habits: [HabitDisplayModel]
    let monthTitle: String
    let calendarDays: [CalendarDayDisplayModel]
    let canNavigateToNextMonth: Bool
    let remindersEnabled: Bool
    let reminderTime: Date
    let reminderStatusText: String
}

enum DashboardViewState: Equatable {
    case loading
    case content(DashboardDisplayModel)
    case error(String)
}

struct DashboardSnapshot {
    let displayedMonth: Date
    let todayRecord: HabitDayRecord
    let calendarRecords: [HabitDayRecord]
    let workoutStreak: Int
    let prayerStreak: Int
    let reminderPreferences: ReminderPreferences
    let reminderAuthorizationStatus: ReminderAuthorizationStatus
    let hasAcknowledgedPrayerGuidance: Bool
}

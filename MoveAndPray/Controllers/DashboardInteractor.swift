import Foundation

@MainActor
protocol DashboardInteractorOutput: AnyObject {
    func dashboardInteractor(_ interactor: DashboardInteractor, didLoad snapshot: DashboardSnapshot)
    func dashboardInteractor(_ interactor: DashboardInteractor, didFail error: Error)
    func dashboardInteractorRemindersAreUnavailable(_ interactor: DashboardInteractor)
}

@MainActor
final class DashboardInteractor {
    private weak var output: DashboardInteractorOutput?
    private let habitStore: HabitStoring
    private let notificationService: NotificationServicing
    private var task: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var requestedMonth: Date?
    private var shouldReportUnavailableReminders = false

    init(
        output: DashboardInteractorOutput,
        habitStore: HabitStoring,
        notificationService: NotificationServicing
    ) {
        self.output = output
        self.habitStore = habitStore
        self.notificationService = notificationService
    }

    deinit {
        task?.cancel()
        authorizationTask?.cancel()
    }

    func load(month: Date) {
        perform(month: month, rescheduleReminders: true)
    }

    func toggle(_ habit: HabitKind, month: Date) {
        habitStore.toggle(habit, on: Date())
        perform(month: month, rescheduleReminders: true)
    }

    func acknowledgePrayerGuidanceAndTogglePrayer(month: Date) {
        habitStore.hasAcknowledgedPrayerGuidance = true
        habitStore.toggle(.prayer, on: Date())
        perform(month: month, rescheduleReminders: true)
    }

    func setRemindersEnabled(_ isEnabled: Bool, month: Date) {
        requestedMonth = month
        authorizationTask?.cancel()
        shouldReportUnavailableReminders = false

        if !isEnabled {
            var preferences = habitStore.reminderPreferences
            preferences.isEnabled = false
            habitStore.reminderPreferences = preferences
            perform(month: month, rescheduleReminders: true)
            return
        }

        // Returning from the system permission prompt triggers load(). Keep the
        // user's enable action alive independently of those lifecycle refreshes.
        authorizationTask = Task { [weak self, notificationService] in
            var status = await notificationService.authorizationStatus()
            guard !Task.isCancelled else { return }

            if status == .notDetermined {
                status = await notificationService.requestAuthorization()
            }
            guard !Task.isCancelled, let self else { return }

            var preferences = habitStore.reminderPreferences
            preferences.isEnabled = status == .authorized
            habitStore.reminderPreferences = preferences
            shouldReportUnavailableReminders = status != .authorized
            perform(month: requestedMonth ?? month, rescheduleReminders: true)
        }
    }

    func setReminderTime(hour: Int, minute: Int, month: Date) {
        var preferences = habitStore.reminderPreferences
        preferences.hour = hour
        preferences.minute = minute
        habitStore.reminderPreferences = preferences
        perform(month: month, rescheduleReminders: true)
    }

    func cancel() {
        task?.cancel()
        authorizationTask?.cancel()
        shouldReportUnavailableReminders = false
    }

    private func perform(month: Date, rescheduleReminders: Bool) {
        requestedMonth = month
        let previousTask = task
        previousTask?.cancel()
        task = Task { [weak self] in
            // UNUserNotificationCenter.add may finish even after cancellation.
            // Wait for it before replacing the schedule so an older add cannot
            // restore a reminder after the latest operation removed it.
            await previousTask?.value
            guard !Task.isCancelled, let self else { return }
            let status = await notificationService.authorizationStatus()
            guard !Task.isCancelled else { return }

            var preferences = habitStore.reminderPreferences
            if status == .denied, preferences.isEnabled {
                preferences.isEnabled = false
                habitStore.reminderPreferences = preferences
            }

            do {
                if rescheduleReminders {
                    try await notificationService.replaceDailyReminders(
                        preferences: preferences,
                        records: upcomingRecords()
                    )
                }
                guard !Task.isCancelled else { return }
                output?.dashboardInteractor(self, didLoad: makeSnapshot(month: month, authorizationStatus: status))
                if shouldReportUnavailableReminders {
                    shouldReportUnavailableReminders = false
                    output?.dashboardInteractorRemindersAreUnavailable(self)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                output?.dashboardInteractor(self, didFail: error)
            }
        }
    }

    private func makeSnapshot(
        month: Date,
        authorizationStatus: ReminderAuthorizationStatus
    ) -> DashboardSnapshot {
        let today = Date()
        let normalizedMonth = AppCalendar.startOfMonth(containing: month)
        return DashboardSnapshot(
            displayedMonth: normalizedMonth,
            todayRecord: habitStore.record(for: today),
            calendarRecords: habitStore.records(for: AppCalendar.gridDates(forMonthContaining: normalizedMonth)),
            workoutStreak: habitStore.currentStreak(for: .workout, asOf: today),
            prayerStreak: habitStore.currentStreak(for: .prayer, asOf: today),
            reminderPreferences: habitStore.reminderPreferences,
            reminderAuthorizationStatus: authorizationStatus,
            hasAcknowledgedPrayerGuidance: habitStore.hasAcknowledgedPrayerGuidance
        )
    }

    private func upcomingRecords() -> [HabitDayRecord] {
        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<32).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        return habitStore.records(for: dates)
    }
}

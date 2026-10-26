import SafariServices
import UIKit

@MainActor
final class DashboardController: UIViewController {
    private let customView = DashboardView()
    private let habitStore: HabitStoring
    private let notificationService: NotificationServicing
    private lazy var interactor = DashboardInteractor(
        output: self,
        habitStore: habitStore,
        notificationService: notificationService
    )

    private var displayedMonth = AppCalendar.startOfMonth(containing: Date())
    private var latestSnapshot: DashboardSnapshot?
    private var hasLoadedContent = false

    init(habitStore: HabitStoring, notificationService: NotificationServicing) {
        self.habitStore = habitStore
        self.notificationService = notificationService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        view = customView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        customView.delegate = self
        customView.applyState(.loading)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        interactor.load(month: displayedMonth)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationDidBecomeActive() {
        interactor.load(month: displayedMonth)
    }

    private func presentPrayerGuidance(mode: PrayerGuidanceController.Mode) {
        guard presentedViewController == nil else { return }
        let controller = PrayerGuidanceController(mode: mode)
        controller.delegate = self
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 28
        }
        present(controller, animated: true)
    }

    private func presentReminderSettingsAlert() {
        let alert = UIAlertController(
            title: L10n.text("alert.notifications_disabled.title"),
            message: L10n.text("alert.notifications_disabled.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.text("alert.not_now"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.text("alert.open_settings"), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    private func presentWebsite(_ page: String) {
        let languagePath = L10n.usesRussian ? "ru/" : ""
        guard presentedViewController == nil,
              let url = URL(string: "https://andreichev.github.io/MoveAndPray/\(languagePath)\(page)/") else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func makeDisplayModel(from snapshot: DashboardSnapshot) -> DashboardDisplayModel {
        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let completedCount = snapshot.todayRecord.completedHabits.count

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")

        let monthFormatter = DateFormatter()
        monthFormatter.locale = .autoupdatingCurrent
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

        let accessibilityDateFormatter = DateFormatter()
        accessibilityDateFormatter.locale = .autoupdatingCurrent
        accessibilityDateFormatter.setLocalizedDateFormatFromTemplate("d MMMM EEEE")

        let habits = [
            HabitDisplayModel(
                kind: .workout,
                title: L10n.text("habit.workout.title"),
                detail: snapshot.todayRecord.isCompleted(.workout)
                    ? L10n.text("habit.completed_today")
                    : L10n.text("habit.workout.detail"),
                actionTitle: snapshot.todayRecord.isCompleted(.workout)
                    ? L10n.text("habit.action.remove")
                    : L10n.text("habit.action.mark"),
                streakText: streakText(snapshot.workoutStreak),
                symbolName: "figure.run",
                isCompleted: snapshot.todayRecord.isCompleted(.workout)
            ),
            HabitDisplayModel(
                kind: .prayer,
                title: L10n.text("habit.prayer.title"),
                detail: snapshot.todayRecord.isCompleted(.prayer)
                    ? L10n.text("habit.completed_today")
                    : L10n.text("habit.prayer.detail"),
                actionTitle: snapshot.todayRecord.isCompleted(.prayer)
                    ? L10n.text("habit.action.remove")
                    : L10n.text("habit.action.mark"),
                streakText: streakText(snapshot.prayerStreak),
                symbolName: "hands.and.sparkles.fill",
                isCompleted: snapshot.todayRecord.isCompleted(.prayer)
            )
        ]

        let calendarDays = snapshot.calendarRecords.map { record in
            let isToday = calendar.isDate(record.date, inSameDayAs: today)
            let inDisplayedMonth = calendar.isDate(record.date, equalTo: snapshot.displayedMonth, toGranularity: .month)
            let workoutState = visualState(for: record, habit: .workout, today: today)
            let prayerState = visualState(for: record, habit: .prayer, today: today)
            return CalendarDayDisplayModel(
                dayText: String(calendar.component(.day, from: record.date)),
                accessibilityText: [
                    accessibilityDateFormatter.string(from: record.date),
                    accessibilityText(for: .workout, state: workoutState),
                    accessibilityText(for: .prayer, state: prayerState)
                ].joined(separator: ". "),
                workoutState: workoutState,
                prayerState: prayerState,
                isInDisplayedMonth: inDisplayedMonth,
                isToday: isToday
            )
        }

        let reminderDate = calendar.date(
            bySettingHour: snapshot.reminderPreferences.hour,
            minute: snapshot.reminderPreferences.minute,
            second: 0,
            of: Date()
        ) ?? Date()

        let currentMonth = AppCalendar.startOfMonth(containing: Date())
        return DashboardDisplayModel(
            dateText: capitalizedFirst(dateFormatter.string(from: Date())),
            progressText: "\(completedCount)/2",
            motivationText: motivation(for: completedCount),
            habits: habits,
            monthTitle: capitalizedFirst(monthFormatter.string(from: snapshot.displayedMonth)),
            calendarDays: calendarDays,
            canNavigateToNextMonth: snapshot.displayedMonth < currentMonth,
            remindersEnabled: snapshot.reminderPreferences.isEnabled,
            reminderTime: reminderDate,
            reminderStatusText: reminderStatusText(from: snapshot)
        )
    }

    private func visualState(
        for record: HabitDayRecord,
        habit: HabitKind,
        today: Date
    ) -> HabitCompletionVisualState {
        if record.isCompleted(habit) { return .completed }
        switch AppCalendar.current.compare(record.date, to: today, toGranularity: .day) {
        case .orderedAscending: return .missed
        case .orderedSame: return .pending
        case .orderedDescending: return .future
        }
    }

    private func accessibilityText(for habit: HabitKind, state: HabitCompletionVisualState) -> String {
        let prefix = habit == .workout ? "calendar.workout" : "calendar.prayer"
        switch state {
        case .completed: return L10n.text("\(prefix).completed")
        case .missed: return L10n.text("\(prefix).missed")
        case .pending: return L10n.text("\(prefix).pending")
        case .future: return L10n.text("\(prefix).future")
        }
    }

    private func reminderStatusText(from snapshot: DashboardSnapshot) -> String {
        if snapshot.reminderAuthorizationStatus == .denied {
            return L10n.text("reminder.status.denied")
        }
        if snapshot.reminderPreferences.isEnabled {
            return L10n.text("reminder.status.enabled")
        }
        return L10n.text("reminder.status.disabled")
    }

    private func motivation(for completedCount: Int) -> String {
        switch completedCount {
        case 0: return L10n.text("motivation.none")
        case 1: return L10n.text("motivation.half")
        default: return L10n.text("motivation.complete")
        }
    }

    private func streakText(_ value: Int) -> String {
        guard value > 0 else { return L10n.text("habit.streak.starts_today") }
        return L10n.plural("streak.days", value: value)
    }

    private func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: .autoupdatingCurrent) + String(text.dropFirst())
    }
}

extension DashboardController: DashboardViewDelegate {
    func dashboardView(_ view: DashboardView, didTap habit: HabitKind) {
        if habit == .prayer,
           latestSnapshot?.todayRecord.isCompleted(.prayer) == false,
           latestSnapshot?.hasAcknowledgedPrayerGuidance == false {
            presentPrayerGuidance(mode: .acknowledgement)
            return
        }
        interactor.toggle(habit, month: displayedMonth)
    }

    func dashboardViewDidTapPrayerGuidance(_ view: DashboardView) {
        presentPrayerGuidance(mode: .information)
    }

    func dashboardViewDidTapPrivacyPolicy(_ view: DashboardView) {
        presentWebsite("privacy")
    }

    func dashboardViewDidTapSupport(_ view: DashboardView) {
        presentWebsite("support")
    }

    func dashboardViewDidTapPreviousMonth(_ view: DashboardView) {
        displayedMonth = AppCalendar.month(byAdding: -1, to: displayedMonth)
        interactor.load(month: displayedMonth)
    }

    func dashboardViewDidTapNextMonth(_ view: DashboardView) {
        let candidate = AppCalendar.month(byAdding: 1, to: displayedMonth)
        let currentMonth = AppCalendar.startOfMonth(containing: Date())
        guard candidate <= currentMonth else { return }
        displayedMonth = candidate
        interactor.load(month: displayedMonth)
    }

    func dashboardView(_ view: DashboardView, didChangeRemindersEnabled isEnabled: Bool) {
        interactor.setRemindersEnabled(isEnabled, month: displayedMonth)
    }

    func dashboardView(_ view: DashboardView, didChangeReminderTime date: Date) {
        let components = AppCalendar.current.dateComponents([.hour, .minute], from: date)
        interactor.setReminderTime(
            hour: components.hour ?? ReminderPreferences.defaultValue.hour,
            minute: components.minute ?? ReminderPreferences.defaultValue.minute,
            month: displayedMonth
        )
    }
}

extension DashboardController: DashboardInteractorOutput {
    func dashboardInteractor(_ interactor: DashboardInteractor, didLoad snapshot: DashboardSnapshot) {
        latestSnapshot = snapshot
        displayedMonth = snapshot.displayedMonth
        hasLoadedContent = true
        customView.applyState(.content(makeDisplayModel(from: snapshot)))
    }

    func dashboardInteractor(_ interactor: DashboardInteractor, didFail error: Error) {
        if !hasLoadedContent {
            customView.applyState(.error(L10n.text("error.load")))
            return
        }

        let alert = UIAlertController(
            title: L10n.text("alert.reminder_failed.title"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.text("alert.ok"), style: .default))
        if presentedViewController == nil {
            present(alert, animated: true)
        }
    }

    func dashboardInteractorRemindersAreUnavailable(_ interactor: DashboardInteractor) {
        guard presentedViewController == nil else { return }
        presentReminderSettingsAlert()
    }
}

extension DashboardController: PrayerGuidanceControllerDelegate {
    func prayerGuidanceControllerDidAcknowledge(_ controller: PrayerGuidanceController) {
        interactor.acknowledgePrayerGuidanceAndTogglePrayer(month: displayedMonth)
    }
}

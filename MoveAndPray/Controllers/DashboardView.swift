import UIKit

@MainActor
protocol DashboardViewDelegate: AnyObject {
    func dashboardView(_ view: DashboardView, didTap habit: HabitKind)
    func dashboardViewDidTapPrayerGuidance(_ view: DashboardView)
    func dashboardViewDidTapPrivacyPolicy(_ view: DashboardView)
    func dashboardViewDidTapSupport(_ view: DashboardView)
    func dashboardViewDidTapPreviousMonth(_ view: DashboardView)
    func dashboardViewDidTapNextMonth(_ view: DashboardView)
    func dashboardView(_ view: DashboardView, didChangeRemindersEnabled isEnabled: Bool)
    func dashboardView(_ view: DashboardView, didChangeReminderTime date: Date)
}

@MainActor
final class DashboardView: UIView {
    weak var delegate: DashboardViewDelegate?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let brandLabel = UILabel()
    private let mottoLabel = UILabel()
    private let dateLabel = UILabel()
    private let summaryView = TodaySummaryView()
    private let workoutView = HabitActionView()
    private let prayerView = HabitActionView()
    private let prayerGuidanceButton = UIButton(type: .system)
    private let privacyPolicyButton = UIButton(type: .system)
    private let supportButton = UIButton(type: .system)
    private let calendarView = MonthCalendarView()
    private let reminderView = ReminderSettingsView()
    private let loadingOverlay = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        addSubviews()
        makeConstraints()
        bindLocalActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func applyState(_ state: DashboardViewState) {
        switch state {
        case .loading:
            loadingOverlay.isHidden = false
            errorLabel.isHidden = true
            activityIndicator.startAnimating()
        case let .content(model):
            activityIndicator.stopAnimating()
            loadingOverlay.isHidden = true
            apply(model)
        case let .error(message):
            activityIndicator.stopAnimating()
            loadingOverlay.isHidden = false
            errorLabel.isHidden = false
            errorLabel.text = message
        }
    }

    private func apply(_ model: DashboardDisplayModel) {
        dateLabel.text = model.dateText
        summaryView.apply(progressText: model.progressText, motivationText: model.motivationText)
        if let workout = model.habits.first(where: { $0.kind == .workout }) {
            workoutView.apply(workout)
        }
        if let prayer = model.habits.first(where: { $0.kind == .prayer }) {
            prayerView.apply(prayer)
        }
        calendarView.apply(
            monthTitle: model.monthTitle,
            days: model.calendarDays,
            canNavigateToNextMonth: model.canNavigateToNextMonth
        )
        reminderView.apply(
            isEnabled: model.remindersEnabled,
            time: model.reminderTime,
            statusText: model.reminderStatusText
        )
    }

    private func setupStyle() {
        backgroundColor = AppTheme.background

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic

        contentStack.axis = .vertical
        contentStack.spacing = 16

        brandLabel.text = "MOVE & PRAY"
        brandLabel.textColor = AppTheme.oxblood
        brandLabel.font = AppTheme.serifFont(size: 14, weight: .bold)
        brandLabel.textAlignment = .center
        brandLabel.accessibilityTraits = .header

        mottoLabel.text = "MEMENTO MORI"
        mottoLabel.textColor = AppTheme.ink
        mottoLabel.font = AppTheme.serifFont(size: 34, weight: .black)
        mottoLabel.textAlignment = .center
        mottoLabel.adjustsFontSizeToFitWidth = true
        mottoLabel.minimumScaleFactor = 0.75

        dateLabel.textColor = AppTheme.mutedInk
        dateLabel.font = AppTheme.roundedFont(size: 15, weight: .medium)
        dateLabel.textAlignment = .center

        var guidanceConfiguration = UIButton.Configuration.plain()
        guidanceConfiguration.image = UIImage(systemName: "book.closed")
        guidanceConfiguration.imagePadding = 8
        guidanceConfiguration.title = L10n.text("dashboard.prayer_guidance")
        guidanceConfiguration.baseForegroundColor = AppTheme.prayer
        guidanceConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        prayerGuidanceButton.configuration = guidanceConfiguration
        prayerGuidanceButton.titleLabel?.font = AppTheme.roundedFont(size: 14, weight: .semibold)
        prayerGuidanceButton.accessibilityHint = L10n.text("dashboard.prayer_guidance.accessibility_hint")

        configureFooterButton(privacyPolicyButton, titleKey: "dashboard.privacy_policy")
        configureFooterButton(supportButton, titleKey: "dashboard.support")

        loadingOverlay.backgroundColor = AppTheme.background
        loadingOverlay.layer.cornerRadius = 20
        errorLabel.textColor = AppTheme.oxblood
        errorLabel.font = AppTheme.roundedFont(size: 15, weight: .medium)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true
    }

    private func addSubviews() {
        addSubview(scrollView)
        scrollView.addSubview(contentStack)

        [brandLabel, mottoLabel, dateLabel, summaryView].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(4, after: brandLabel)
        contentStack.setCustomSpacing(2, after: mottoLabel)
        contentStack.setCustomSpacing(24, after: dateLabel)

        contentStack.addArrangedSubview(makeSectionTitle(L10n.text("dashboard.section.today")))
        contentStack.addArrangedSubview(workoutView)
        contentStack.addArrangedSubview(prayerView)
        contentStack.addArrangedSubview(prayerGuidanceButton)
        contentStack.setCustomSpacing(26, after: prayerGuidanceButton)

        contentStack.addArrangedSubview(makeSectionTitle(L10n.text("dashboard.section.calendar")))
        contentStack.addArrangedSubview(calendarView)
        contentStack.setCustomSpacing(26, after: calendarView)

        contentStack.addArrangedSubview(makeSectionTitle(L10n.text("dashboard.section.reminder")))
        contentStack.addArrangedSubview(reminderView)

        let footer = UILabel()
        footer.text = "ERAM QUOD ES · ERIS QUOD SUM"
        footer.textColor = AppTheme.mutedInk
        footer.font = AppTheme.serifFont(size: 12, weight: .semibold)
        footer.textAlignment = .center
        footer.numberOfLines = 0
        contentStack.addArrangedSubview(footer)
        contentStack.setCustomSpacing(30, after: reminderView)

        let linksStack = UIStackView(arrangedSubviews: [privacyPolicyButton, supportButton])
        linksStack.axis = .vertical
        linksStack.alignment = .fill
        linksStack.spacing = 0
        contentStack.addArrangedSubview(linksStack)

        addSubview(loadingOverlay)
        loadingOverlay.addSubview(activityIndicator)
        loadingOverlay.addSubview(errorLabel)
    }

    private func makeConstraints() {
        [scrollView, contentStack, loadingOverlay, activityIndicator, errorLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),

            workoutView.heightAnchor.constraint(greaterThanOrEqualToConstant: 112),
            prayerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 112),
            privacyPolicyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            supportButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            loadingOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingOverlay.widthAnchor.constraint(equalToConstant: 260),
            loadingOverlay.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
            errorLabel.topAnchor.constraint(equalTo: loadingOverlay.topAnchor, constant: 24),
            errorLabel.leadingAnchor.constraint(equalTo: loadingOverlay.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: loadingOverlay.trailingAnchor, constant: -20),
            errorLabel.bottomAnchor.constraint(equalTo: loadingOverlay.bottomAnchor, constant: -24)
        ])
    }

    private func bindLocalActions() {
        workoutView.addTarget(self, action: #selector(didTapWorkout), for: .touchUpInside)
        prayerView.addTarget(self, action: #selector(didTapPrayer), for: .touchUpInside)
        prayerGuidanceButton.addTarget(self, action: #selector(didTapPrayerGuidance), for: .touchUpInside)
        privacyPolicyButton.addTarget(self, action: #selector(didTapPrivacyPolicy), for: .touchUpInside)
        supportButton.addTarget(self, action: #selector(didTapSupport), for: .touchUpInside)
        calendarView.delegate = self
        reminderView.delegate = self
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = AppTheme.mutedInk
        label.font = AppTheme.roundedFont(size: 12, weight: .bold)
        label.accessibilityTraits = .header
        return label
    }

    private func configureFooterButton(_ button: UIButton, titleKey: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.text(titleKey)
        configuration.baseForegroundColor = AppTheme.prayer
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(size: 14, weight: .medium)
            return attributes
        }
        button.configuration = configuration
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.accessibilityHint = L10n.text("dashboard.website.accessibility_hint")
    }

    @objc private func didTapWorkout() {
        delegate?.dashboardView(self, didTap: .workout)
    }

    @objc private func didTapPrayer() {
        delegate?.dashboardView(self, didTap: .prayer)
    }

    @objc private func didTapPrayerGuidance() {
        delegate?.dashboardViewDidTapPrayerGuidance(self)
    }

    @objc private func didTapPrivacyPolicy() {
        delegate?.dashboardViewDidTapPrivacyPolicy(self)
    }

    @objc private func didTapSupport() {
        delegate?.dashboardViewDidTapSupport(self)
    }
}

extension DashboardView: MonthCalendarViewDelegate {
    func monthCalendarViewDidTapPrevious(_ view: MonthCalendarView) {
        delegate?.dashboardViewDidTapPreviousMonth(self)
    }

    func monthCalendarViewDidTapNext(_ view: MonthCalendarView) {
        delegate?.dashboardViewDidTapNextMonth(self)
    }
}

extension DashboardView: ReminderSettingsViewDelegate {
    func reminderSettingsView(_ view: ReminderSettingsView, didChangeEnabled isEnabled: Bool) {
        delegate?.dashboardView(self, didChangeRemindersEnabled: isEnabled)
    }

    func reminderSettingsView(_ view: ReminderSettingsView, didChangeTime date: Date) {
        delegate?.dashboardView(self, didChangeReminderTime: date)
    }
}

@MainActor
private final class TodaySummaryView: UIView {
    private let progressLabel = UILabel()
    private let motivationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.ink
        layer.cornerRadius = 22

        progressLabel.textColor = AppTheme.surface
        progressLabel.font = AppTheme.serifFont(size: 40, weight: .black)
        progressLabel.textAlignment = .center
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)
        progressLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        motivationLabel.textColor = AppTheme.surface.withAlphaComponent(0.8)
        motivationLabel.font = AppTheme.roundedFont(size: 14, weight: .medium)
        motivationLabel.numberOfLines = 0
        motivationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [progressLabel, motivationLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 18
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(progressText: String, motivationText: String) {
        progressLabel.text = progressText
        motivationLabel.text = motivationText
        accessibilityLabel = L10n.format("dashboard.progress.accessibility", progressText, motivationText)
    }
}

@MainActor
private final class HabitActionView: UIControl {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let streakLabel = UILabel()
    private let actionLabel = UILabel()
    private let statusImageView = UIImageView()

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
                self.alpha = self.isHighlighted ? 0.86 : 1
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        addSubviews()
        makeConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(_ model: HabitDisplayModel) {
        let accent = model.kind == .workout ? AppTheme.workout : AppTheme.prayer
        iconImageView.image = UIImage(systemName: model.symbolName)
        iconImageView.tintColor = accent
        iconContainer.backgroundColor = accent.withAlphaComponent(0.12)
        titleLabel.text = model.title
        detailLabel.text = model.detail
        streakLabel.text = model.streakText
        streakLabel.textColor = accent
        actionLabel.text = model.actionTitle
        actionLabel.textColor = accent
        statusImageView.image = UIImage(systemName: model.isCompleted ? "checkmark.circle.fill" : "circle")
        statusImageView.tintColor = model.isCompleted ? accent : AppTheme.stone
        backgroundColor = model.isCompleted ? accent.withAlphaComponent(0.075) : AppTheme.surface
        layer.borderColor = (model.isCompleted ? accent.withAlphaComponent(0.35) : AppTheme.line).cgColor
        accessibilityLabel = "\(model.title). \(model.detail). \(model.streakText). \(model.actionTitle)"
        accessibilityTraits = model.isCompleted ? [.button, .selected] : .button
    }

    private func setupStyle() {
        backgroundColor = AppTheme.surface
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = AppTheme.line.cgColor
        isAccessibilityElement = true

        iconContainer.layer.cornerRadius = 18
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)

        titleLabel.textColor = AppTheme.ink
        titleLabel.font = AppTheme.serifFont(size: 21, weight: .bold)
        detailLabel.textColor = AppTheme.mutedInk
        detailLabel.font = AppTheme.roundedFont(size: 13, weight: .regular)
        detailLabel.numberOfLines = 2
        streakLabel.font = AppTheme.roundedFont(size: 12, weight: .bold)
        actionLabel.font = AppTheme.roundedFont(size: 12, weight: .bold)
        statusImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
    }

    private func addSubviews() {
        addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        addSubview(statusImageView)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        addSubview(textStack)

        let metadataStack = UIStackView(arrangedSubviews: [streakLabel, UIView(), actionLabel])
        metadataStack.axis = .horizontal
        metadataStack.alignment = .center
        addSubview(metadataStack)

        [iconContainer, iconImageView, statusImageView, textStack, metadataStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 52),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),

            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusImageView.leadingAnchor, constant: -10),

            statusImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            statusImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusImageView.widthAnchor.constraint(equalToConstant: 28),
            statusImageView.heightAnchor.constraint(equalToConstant: 28),

            metadataStack.topAnchor.constraint(greaterThanOrEqualTo: textStack.bottomAnchor, constant: 10),
            metadataStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            metadataStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            metadataStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    private func makeConstraints() {}
}

@MainActor
protocol MonthCalendarViewDelegate: AnyObject {
    func monthCalendarViewDidTapPrevious(_ view: MonthCalendarView)
    func monthCalendarViewDidTapNext(_ view: MonthCalendarView)
}

@MainActor
final class MonthCalendarView: UIView {
    weak var delegate: MonthCalendarViewDelegate?

    private let monthLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var dayViews: [CalendarDayView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        addSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(monthTitle: String, days: [CalendarDayDisplayModel], canNavigateToNextMonth: Bool) {
        monthLabel.text = monthTitle
        nextButton.isEnabled = canNavigateToNextMonth
        nextButton.alpha = canNavigateToNextMonth ? 1 : 0.28
        for (view, model) in zip(dayViews, days) {
            view.apply(model)
        }
    }

    private func setupStyle() {
        backgroundColor = AppTheme.surface
        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = AppTheme.line.cgColor

        monthLabel.textColor = AppTheme.ink
        monthLabel.font = AppTheme.serifFont(size: 20, weight: .bold)
        monthLabel.textAlignment = .center

        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        [previousButton, nextButton].forEach {
            $0.tintColor = AppTheme.ink
            $0.accessibilityTraits = .button
        }
        previousButton.accessibilityLabel = L10n.text("calendar.previous_month")
        nextButton.accessibilityLabel = L10n.text("calendar.next_month")
    }

    private func addSubviews() {
        let header = UIStackView(arrangedSubviews: [previousButton, monthLabel, nextButton])
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .fill
        previousButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        nextButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let weekdayStack = UIStackView()
        weekdayStack.axis = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.spacing = 4
        localizedWeekdaySymbols().forEach { title in
            let label = UILabel()
            label.text = title
            label.textColor = AppTheme.mutedInk
            label.font = AppTheme.roundedFont(size: 10, weight: .bold)
            label.textAlignment = .center
            weekdayStack.addArrangedSubview(label)
        }

        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 4
        for _ in 0..<6 {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 4
            for _ in 0..<7 {
                let dayView = CalendarDayView()
                dayView.heightAnchor.constraint(equalToConstant: 48).isActive = true
                row.addArrangedSubview(dayView)
                dayViews.append(dayView)
            }
            gridStack.addArrangedSubview(row)
        }

        let legend = UIStackView(arrangedSubviews: [
            makeLegend(color: AppTheme.workout, text: L10n.text("calendar.legend.workout")),
            makeLegend(color: AppTheme.prayer, text: L10n.text("calendar.legend.prayer")),
            UIView()
        ])
        legend.axis = .horizontal
        legend.spacing = 14
        legend.alignment = .center

        let stack = UIStackView(arrangedSubviews: [header, weekdayStack, gridStack, legend])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(14, after: gridStack)
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        previousButton.addTarget(self, action: #selector(didTapPrevious), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
    }

    private func makeLegend(color: UIColor, text: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let label = UILabel()
        label.text = text
        label.textColor = AppTheme.mutedInk
        label.font = AppTheme.roundedFont(size: 11)

        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        return stack
    }

    private func localizedWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        guard let symbols = formatter.shortStandaloneWeekdaySymbols, symbols.count == 7 else {
            return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        }
        let mondayFirst = Array(symbols[1...6]) + [symbols[0]]
        return mondayFirst.map { $0.uppercased(with: .autoupdatingCurrent) }
    }

    @objc private func didTapPrevious() {
        delegate?.monthCalendarViewDidTapPrevious(self)
    }

    @objc private func didTapNext() {
        delegate?.monthCalendarViewDidTapNext(self)
    }
}

@MainActor
private final class CalendarDayView: UIView {
    private let dayLabel = UILabel()
    private let workoutDot = CompletionDotView()
    private let prayerDot = CompletionDotView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        dayLabel.textColor = AppTheme.ink
        dayLabel.font = AppTheme.roundedFont(size: 13, weight: .semibold)
        dayLabel.textAlignment = .center

        let dots = UIStackView(arrangedSubviews: [workoutDot, prayerDot])
        dots.axis = .horizontal
        dots.spacing = 4
        dots.alignment = .center

        let stack = UIStackView(arrangedSubviews: [dayLabel, dots])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            workoutDot.widthAnchor.constraint(equalToConstant: 7),
            workoutDot.heightAnchor.constraint(equalToConstant: 7),
            prayerDot.widthAnchor.constraint(equalToConstant: 7),
            prayerDot.heightAnchor.constraint(equalToConstant: 7)
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(_ model: CalendarDayDisplayModel) {
        dayLabel.text = model.dayText
        workoutDot.apply(state: model.workoutState, accent: AppTheme.workout)
        prayerDot.apply(state: model.prayerState, accent: AppTheme.prayer)
        alpha = model.isInDisplayedMonth ? 1 : 0.3
        backgroundColor = model.isToday ? AppTheme.ink.withAlphaComponent(0.08) : .clear
        layer.borderWidth = model.isToday ? 1 : 0
        layer.borderColor = AppTheme.ink.withAlphaComponent(0.32).cgColor
        accessibilityLabel = model.accessibilityText
    }
}

@MainActor
private final class CompletionDotView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 3.5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(state: HabitCompletionVisualState, accent: UIColor) {
        switch state {
        case .completed:
            backgroundColor = accent
            layer.borderWidth = 0
        case .missed:
            backgroundColor = .clear
            layer.borderWidth = 1.3
            layer.borderColor = AppTheme.oxblood.withAlphaComponent(0.72).cgColor
        case .pending:
            backgroundColor = .clear
            layer.borderWidth = 1.3
            layer.borderColor = accent.withAlphaComponent(0.7).cgColor
        case .future:
            backgroundColor = AppTheme.line.withAlphaComponent(0.45)
            layer.borderWidth = 0
        }
    }
}

@MainActor
protocol ReminderSettingsViewDelegate: AnyObject {
    func reminderSettingsView(_ view: ReminderSettingsView, didChangeEnabled isEnabled: Bool)
    func reminderSettingsView(_ view: ReminderSettingsView, didChangeTime date: Date)
}

@MainActor
final class ReminderSettingsView: UIView {
    weak var delegate: ReminderSettingsViewDelegate?

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let reminderSwitch = UISwitch()
    private let timePicker = UIDatePicker()
    private var isApplyingState = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        addSubviews()
        bindLocalActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func apply(isEnabled: Bool, time: Date, statusText: String) {
        isApplyingState = true
        reminderSwitch.setOn(isEnabled, animated: false)
        timePicker.date = time
        timePicker.isEnabled = isEnabled
        timePicker.alpha = isEnabled ? 1 : 0.45
        statusLabel.text = statusText
        isApplyingState = false
    }

    private func setupStyle() {
        backgroundColor = AppTheme.surface
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = AppTheme.line.cgColor

        titleLabel.text = L10n.text("reminder.title")
        titleLabel.textColor = AppTheme.ink
        titleLabel.font = AppTheme.serifFont(size: 19, weight: .bold)
        statusLabel.textColor = AppTheme.mutedInk
        statusLabel.font = AppTheme.roundedFont(size: 13)
        statusLabel.numberOfLines = 0

        reminderSwitch.onTintColor = AppTheme.oxblood
        reminderSwitch.accessibilityLabel = L10n.text("reminder.toggle.accessibility")

        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        timePicker.tintColor = AppTheme.oxblood
        timePicker.accessibilityLabel = L10n.text("reminder.time.accessibility")
    }

    private func addSubviews() {
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), reminderSwitch])
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        let timeTitle = UILabel()
        timeTitle.text = L10n.text("reminder.time.title")
        timeTitle.textColor = AppTheme.mutedInk
        timeTitle.font = AppTheme.roundedFont(size: 14, weight: .medium)
        let timeRow = UIStackView(arrangedSubviews: [timeTitle, UIView(), timePicker])
        timeRow.axis = .horizontal
        timeRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleRow, statusLabel, timeRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(16, after: statusLabel)
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    private func bindLocalActions() {
        reminderSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        timePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
    }

    @objc private func switchChanged() {
        guard !isApplyingState else { return }
        delegate?.reminderSettingsView(self, didChangeEnabled: reminderSwitch.isOn)
    }

    @objc private func timeChanged() {
        guard !isApplyingState else { return }
        delegate?.reminderSettingsView(self, didChangeTime: timePicker.date)
    }
}

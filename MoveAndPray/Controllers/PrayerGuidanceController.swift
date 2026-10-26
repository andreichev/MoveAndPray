import SafariServices
import UIKit

@MainActor
protocol PrayerGuidanceControllerDelegate: AnyObject {
    func prayerGuidanceControllerDidAcknowledge(_ controller: PrayerGuidanceController)
}

@MainActor
final class PrayerGuidanceController: UIViewController {
    enum Mode {
        case information
        case acknowledgement
    }

    weak var delegate: PrayerGuidanceControllerDelegate?

    private let customView: PrayerGuidanceView
    private let mode: Mode
    private var sourceURL: URL {
        let url = L10n.usesRussian
            ? "https://azbyka.ru/otechnik/Feofan_Zatvornik/o-molitve/"
            : "https://azbyka.ru/otechnik/Feofan_Zatvornik/on-prayer/"
        return URL(string: url)!
    }

    init(mode: Mode) {
        self.mode = mode
        self.customView = PrayerGuidanceView(
            primaryButtonTitle: mode == .acknowledgement
                ? L10n.text("prayer.primary.acknowledge")
                : L10n.text("prayer.primary.close")
        )
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
    }
}

extension PrayerGuidanceController: PrayerGuidanceViewDelegate {
    func prayerGuidanceViewDidTapSource(_ view: PrayerGuidanceView) {
        present(SFSafariViewController(url: sourceURL), animated: true)
    }

    func prayerGuidanceViewDidTapPrimary(_ view: PrayerGuidanceView) {
        if mode == .acknowledgement {
            delegate?.prayerGuidanceControllerDidAcknowledge(self)
        }
        dismiss(animated: true)
    }
}

@MainActor
protocol PrayerGuidanceViewDelegate: AnyObject {
    func prayerGuidanceViewDidTapSource(_ view: PrayerGuidanceView)
    func prayerGuidanceViewDidTapPrimary(_ view: PrayerGuidanceView)
}

@MainActor
final class PrayerGuidanceView: UIView {
    weak var delegate: PrayerGuidanceViewDelegate?

    private let primaryButtonTitle: String
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let primaryButton = UIButton(type: .system)
    private let sourceButton = UIButton(type: .system)

    init(primaryButtonTitle: String) {
        self.primaryButtonTitle = primaryButtonTitle
        super.init(frame: .zero)
        setupStyle()
        addSubviews()
        makeConstraints()
        bindLocalActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func setupStyle() {
        backgroundColor = AppTheme.background
        scrollView.contentInsetAdjustmentBehavior = .never

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16

        var primaryConfiguration = UIButton.Configuration.filled()
        primaryConfiguration.title = primaryButtonTitle
        primaryConfiguration.baseBackgroundColor = AppTheme.prayer
        primaryConfiguration.baseForegroundColor = .white
        primaryConfiguration.cornerStyle = .large
        primaryConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        primaryButton.configuration = primaryConfiguration

        var sourceConfiguration = UIButton.Configuration.plain()
        sourceConfiguration.title = L10n.text("prayer.source.title")
        sourceConfiguration.image = UIImage(systemName: "arrow.up.right.square")
        sourceConfiguration.imagePadding = 8
        sourceConfiguration.baseForegroundColor = AppTheme.prayer
        sourceButton.configuration = sourceConfiguration
        sourceButton.titleLabel?.font = AppTheme.roundedFont(size: 14, weight: .semibold)
        sourceButton.accessibilityHint = L10n.text("prayer.source.accessibility_hint")
    }

    private func addSubviews() {
        let handle = UIView()
        handle.backgroundColor = AppTheme.stone
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.widthAnchor.constraint(equalToConstant: 42).isActive = true
        handle.heightAnchor.constraint(equalToConstant: 5).isActive = true
        let handleRow = UIView()
        handleRow.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.centerXAnchor.constraint(equalTo: handleRow.centerXAnchor),
            handle.topAnchor.constraint(equalTo: handleRow.topAnchor),
            handle.bottomAnchor.constraint(equalTo: handleRow.bottomAnchor)
        ])

        let symbolContainer = UIView()
        symbolContainer.backgroundColor = AppTheme.prayer.withAlphaComponent(0.1)
        symbolContainer.layer.cornerRadius = 28
        symbolContainer.translatesAutoresizingMaskIntoConstraints = false
        symbolContainer.widthAnchor.constraint(equalToConstant: 56).isActive = true
        symbolContainer.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let symbol = UIImageView(image: UIImage(systemName: "hands.and.sparkles.fill"))
        symbol.tintColor = AppTheme.prayer
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .medium)
        symbolContainer.addSubview(symbol)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            symbol.centerXAnchor.constraint(equalTo: symbolContainer.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: symbolContainer.centerYAnchor)
        ])
        let symbolRow = UIView()
        symbolRow.addSubview(symbolContainer)
        NSLayoutConstraint.activate([
            symbolContainer.centerXAnchor.constraint(equalTo: symbolRow.centerXAnchor),
            symbolContainer.topAnchor.constraint(equalTo: symbolRow.topAnchor),
            symbolContainer.bottomAnchor.constraint(equalTo: symbolRow.bottomAnchor)
        ])

        let title = makeLabel(
            text: L10n.text("prayer.guidance.title"),
            font: AppTheme.serifFont(size: 27, weight: .bold),
            color: AppTheme.ink,
            alignment: .center
        )
        title.accessibilityTraits = .header

        let disclaimer = makeLabel(
            text: L10n.text("prayer.guidance.disclaimer"),
            font: AppTheme.roundedFont(size: 16),
            color: AppTheme.ink,
            alignment: .left
        )

        let advice = makeLabel(
            text: L10n.text("prayer.guidance.advice"),
            font: AppTheme.roundedFont(size: 14),
            color: AppTheme.mutedInk,
            alignment: .left
        )

        let quote = makeLabel(
            text: L10n.text("prayer.guidance.quote"),
            font: AppTheme.serifFont(size: 16, weight: .semibold),
            color: AppTheme.prayer,
            alignment: .center
        )
        quote.backgroundColor = AppTheme.surface
        quote.layer.cornerRadius = 16
        quote.layer.masksToBounds = true
        quote.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

        [
            handleRow,
            symbolRow,
            title,
            disclaimer,
            quote,
            advice,
            sourceButton,
            primaryButton
        ].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(12, after: handleRow)
        contentStack.setCustomSpacing(10, after: symbolRow)
        contentStack.setCustomSpacing(22, after: title)
        contentStack.setCustomSpacing(22, after: advice)
        contentStack.setCustomSpacing(12, after: sourceButton)
        contentStack.setCustomSpacing(12, after: quote)

        addSubview(scrollView)
        scrollView.addSubview(contentStack)
    }

    private func makeConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 10),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 22),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -22),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -44),
            sourceButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func bindLocalActions() {
        sourceButton.addTarget(self, action: #selector(didTapSource), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
    }

    private func makeLabel(
        text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) -> InsetLabel {
        let label = InsetLabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        return label
    }

    @objc private func didTapSource() {
        delegate?.prayerGuidanceViewDidTapSource(self)
    }

    @objc private func didTapPrimary() {
        delegate?.prayerGuidanceViewDidTapPrimary(self)
    }
}

@MainActor
private final class InsetLabel: UILabel {
    private var textInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: directionalLayoutMargins.top,
            left: directionalLayoutMargins.leading,
            bottom: directionalLayoutMargins.bottom,
            right: directionalLayoutMargins.trailing
        )
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insets = textInsets
        let textRect = super.textRect(
            forBounds: bounds.inset(by: insets),
            limitedToNumberOfLines: numberOfLines
        )
        return textRect.inset(by: UIEdgeInsets(
            top: -insets.top,
            left: -insets.left,
            bottom: -insets.bottom,
            right: -insets.right
        ))
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
}

import UIKit

enum AppTheme {
    static let background = UIColor(red: 0.955, green: 0.941, blue: 0.902, alpha: 1)
    static let surface = UIColor(red: 0.995, green: 0.986, blue: 0.956, alpha: 1)
    static let ink = UIColor(red: 0.105, green: 0.094, blue: 0.082, alpha: 1)
    static let mutedInk = UIColor(red: 0.39, green: 0.36, blue: 0.31, alpha: 1)
    static let stone = UIColor(red: 0.77, green: 0.73, blue: 0.65, alpha: 1)
    static let line = UIColor(red: 0.85, green: 0.81, blue: 0.73, alpha: 1)
    static let oxblood = UIColor(red: 0.43, green: 0.075, blue: 0.075, alpha: 1)
    static let workout = UIColor(red: 0.72, green: 0.39, blue: 0.08, alpha: 1)
    static let prayer = UIColor(red: 0.12, green: 0.28, blue: 0.44, alpha: 1)

    static func serifFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func roundedFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

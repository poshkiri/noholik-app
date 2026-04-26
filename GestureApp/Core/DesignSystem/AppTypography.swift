import SwiftUI

/// Typography tokens. Use these instead of `.font(...)` directly so text scales
/// consistently with Dynamic Type (critical for accessibility).
enum AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title      = Font.system(.title, design: .rounded, weight: .bold)
    static let title2     = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline   = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body       = Font.system(.body, design: .rounded)
    static let bodyBold   = Font.system(.body, design: .rounded, weight: .semibold)
    static let subheadline = Font.system(.subheadline, design: .rounded)
    static let caption    = Font.system(.caption, design: .rounded)
}

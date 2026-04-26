import SwiftUI

/// Semantic color tokens for the app.
///
/// We use semantic names (not raw color names) so the palette can evolve without
/// rippling changes through every view. Adjusts for light/dark modes automatically.
enum AppColor {
    static let background = Color(light: .init(white: 0.98), dark: .init(white: 0.07))
    static let surface = Color(light: .white, dark: .init(white: 0.12))
    static let surfaceElevated = Color(light: .white, dark: .init(white: 0.16))

    static let textPrimary = Color(light: .init(white: 0.08), dark: .init(white: 0.96))
    static let textSecondary = Color(light: .init(white: 0.38), dark: .init(white: 0.72))
    static let textOnAccent = Color.white

    static let accent = Color(light: .init(red: 0.95, green: 0.32, blue: 0.45),
                              dark:  .init(red: 1.00, green: 0.44, blue: 0.56))
    static let accentSoft = Color(light: .init(red: 0.98, green: 0.90, blue: 0.92),
                                  dark:  .init(red: 0.30, green: 0.14, blue: 0.18))

    static let success = Color(red: 0.20, green: 0.75, blue: 0.45)
    static let danger  = Color(red: 0.92, green: 0.30, blue: 0.30)
    static let warning = Color(red: 0.98, green: 0.70, blue: 0.20)

    static let divider = Color(light: .init(white: 0.90), dark: .init(white: 0.22))
}

private extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

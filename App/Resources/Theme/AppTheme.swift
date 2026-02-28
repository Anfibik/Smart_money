import SwiftUI
import UIKit

enum AppTheme {
    // Default theme colors (single theme). Edit these values directly if you want to tune dark mode.
    private static let darkAppBackground = UIColor(red: 0.20, green: 0.21, blue: 0.23, alpha: 1.0)
    private static let darkPanelBackground = UIColor(red: 0.17, green: 0.20, blue: 0.25, alpha: 1.0)
    private static let darkCardBackground = UIColor(red: 0.19, green: 0.23, blue: 0.29, alpha: 1.0)
    private static let darkDisabledCardBackground = UIColor(red: 0.24, green: 0.27, blue: 0.33, alpha: 1.0)
    private static let darkSideMenuBackground = UIColor(red: 0.16, green: 0.19, blue: 0.24, alpha: 1.0)
    private static let darkSideMenuOverlay = UIColor(red: 0.25, green: 0.28, blue: 0.33, alpha: 1.0)

    static var appBackground: Color {
        dynamic(light: .systemBackground, dark: darkAppBackground)
    }

    static var panelBackground: Color {
        dynamic(light: .systemGray6, dark: darkPanelBackground)
    }

    static var cardBackground: Color {
        dynamic(light: .systemBackground, dark: darkCardBackground)
    }

    static var disabledCardBackground: Color {
        dynamic(light: .systemGray5, dark: darkDisabledCardBackground)
    }

    static var sideMenuBackground: Color {
        dynamic(light: .systemGray6, dark: darkSideMenuBackground)
    }

    static var sideMenuOverlay: Color {
        dynamic(light: UIColor.black.withAlphaComponent(0.16), dark: darkSideMenuOverlay.withAlphaComponent(0.32))
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

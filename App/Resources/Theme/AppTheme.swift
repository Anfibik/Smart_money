import SwiftUI
import UIKit

enum AppTheme {
    private static let background = UIColor(red: 0.157, green: 0.165, blue: 0.212, alpha: 1.0) // #282A36
    private static let currentLine = UIColor(red: 0.267, green: 0.278, blue: 0.353, alpha: 1.0) // #44475A
    private static let card = UIColor(red: 0.200, green: 0.208, blue: 0.267, alpha: 1.0)
    private static let disabledCard = UIColor(red: 0.180, green: 0.188, blue: 0.239, alpha: 1.0)
    private static let comment = UIColor(red: 0.384, green: 0.447, blue: 0.643, alpha: 1.0) // #6272A4
    private static let foreground = UIColor(red: 0.973, green: 0.973, blue: 0.949, alpha: 1.0) // #F8F8F2
    private static let purple = UIColor(red: 0.741, green: 0.576, blue: 0.976, alpha: 1.0) // #BD93F9
    private static let cyan = UIColor(red: 0.545, green: 0.914, blue: 0.992, alpha: 1.0) // #8BE9FD
    private static let green = UIColor(red: 0.314, green: 0.980, blue: 0.482, alpha: 1.0) // #50FA7B
    private static let orange = UIColor(red: 1.000, green: 0.722, blue: 0.424, alpha: 1.0) // #FFB86C
    private static let red = UIColor(red: 1.000, green: 0.333, blue: 0.333, alpha: 1.0) // #FF5555
    private static let pink = UIColor(red: 1.000, green: 0.475, blue: 0.776, alpha: 1.0) // #FF79C6

    static var appBackground: Color {
        fixed(background)
    }

    static var panelBackground: Color {
        fixed(currentLine)
    }

    static var cardBackground: Color {
        fixed(card)
    }

    static var disabledCardBackground: Color {
        fixed(disabledCard)
    }

    static var sideMenuBackground: Color {
        fixed(currentLine)
    }

    static var sideMenuOverlay: Color {
        fixed(UIColor.black.withAlphaComponent(0.48))
    }

    static var accent: Color {
        fixed(purple)
    }

    static var positive: Color {
        fixed(green)
    }

    static var negative: Color {
        fixed(red)
    }

    static var warning: Color {
        fixed(orange)
    }

    static var info: Color {
        fixed(cyan)
    }

    static var highlight: Color {
        fixed(pink)
    }

    static var mutedIcon: Color {
        fixed(comment)
    }

    static var primaryText: Color {
        fixed(foreground)
    }

    static var secondaryText: Color {
        fixed(comment)
    }

    private static func fixed(_ color: UIColor) -> Color {
        Color(uiColor: color)
    }
}

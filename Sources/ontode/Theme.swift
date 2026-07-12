import AppKit
import Splash
import SwiftUI

enum AppTheme: String, CaseIterable {
    case solarizedDark
    case solarizedLight

    var colorScheme: ColorScheme {
        self == .solarizedDark ? .dark : .light
    }

    var canvas: Color { Color(nsColor: nsCanvas) }
    var raised: Color { Color(nsColor: nsRaised) }
    var text: Color { Color(nsColor: nsText) }
    var emphasis: Color { Color(nsColor: nsEmphasis) }
    var secondary: Color { Color(nsColor: nsSecondary) }
    var accent: Color { Color(nsColor: Solarized.blue) }
    var border: Color { secondary.opacity(0.35) }

    var splashTheme: Splash.Theme {
        Splash.Theme(
            font: Splash.Font(size: 12.5),
            plainTextColor: nsText,
            tokenColors: [
                .keyword: Solarized.green,
                .string: Solarized.cyan,
                .type: Solarized.yellow,
                .call: Solarized.blue,
                .number: Solarized.magenta,
                .comment: nsSecondary,
                .property: Solarized.blue,
                .dotAccess: Solarized.orange,
                .preprocessing: Solarized.orange,
            ],
            backgroundColor: nsRaised
        )
    }

    private var nsCanvas: NSColor {
        self == .solarizedDark ? Solarized.base03 : Solarized.base3
    }

    private var nsRaised: NSColor {
        self == .solarizedDark ? Solarized.base02 : Solarized.base2
    }

    private var nsText: NSColor {
        self == .solarizedDark ? Solarized.base0 : Solarized.base00
    }

    private var nsEmphasis: NSColor {
        self == .solarizedDark ? Solarized.base1 : Solarized.base01
    }

    private var nsSecondary: NSColor {
        self == .solarizedDark ? Solarized.base01 : Solarized.base1
    }
}

enum Solarized {
    static let base03 = rgb(0, 43, 54)
    static let base02 = rgb(7, 54, 66)
    static let base01 = rgb(88, 110, 117)
    static let base00 = rgb(101, 123, 131)
    static let base0 = rgb(131, 148, 150)
    static let base1 = rgb(147, 161, 161)
    static let base2 = rgb(238, 232, 213)
    static let base3 = rgb(253, 246, 227)
    static let yellow = rgb(181, 137, 0)
    static let orange = rgb(203, 75, 22)
    static let red = rgb(220, 50, 47)
    static let magenta = rgb(211, 54, 130)
    static let violet = rgb(108, 113, 196)
    static let blue = rgb(38, 139, 210)
    static let cyan = rgb(42, 161, 152)
    static let green = rgb(133, 153, 0)

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.solarizedDark
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

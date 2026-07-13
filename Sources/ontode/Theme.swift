import AppKit
import Splash
import SwiftUI

enum AppTheme: String, CaseIterable {
    case dark
    case light

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    var canvas: SwiftUI.Color { SwiftUI.Color(nsColor: nsCanvas) }
    var sidebar: SwiftUI.Color { SwiftUI.Color(nsColor: nsSidebar) }
    var raised: SwiftUI.Color { SwiftUI.Color(nsColor: nsRaised) }
    var text: SwiftUI.Color { SwiftUI.Color(nsColor: nsText) }
    var emphasis: SwiftUI.Color { SwiftUI.Color(nsColor: nsEmphasis) }
    var secondary: SwiftUI.Color { SwiftUI.Color(nsColor: nsSecondary) }
    var accent: SwiftUI.Color { SwiftUI.Color(nsColor: nsAccent) }
    var border: SwiftUI.Color { emphasis.opacity(self == .dark ? 0.12 : 0.10) }

    var splashTheme: Splash.Theme {
        let tokens: [TokenType: Splash.Color]
        switch self {
        case .dark:
            tokens = [
                .keyword: Self.rgb(198, 120, 221),
                .string: Self.rgb(152, 195, 121),
                .type: Self.rgb(229, 192, 123),
                .call: Self.rgb(97, 175, 239),
                .number: Self.rgb(209, 154, 102),
                .comment: nsSecondary,
                .property: Self.rgb(97, 175, 239),
                .dotAccess: Self.rgb(86, 182, 194),
                .preprocessing: Self.rgb(224, 108, 117),
            ]
        case .light:
            tokens = [
                .keyword: Self.rgb(166, 38, 164),
                .string: Self.rgb(80, 161, 79),
                .type: Self.rgb(193, 132, 1),
                .call: Self.rgb(64, 120, 242),
                .number: Self.rgb(152, 104, 1),
                .comment: nsSecondary,
                .property: Self.rgb(64, 120, 242),
                .dotAccess: Self.rgb(1, 132, 188),
                .preprocessing: Self.rgb(228, 86, 73),
            ]
        }
        return Splash.Theme(
            font: Splash.Font(size: 12.5),
            plainTextColor: nsText,
            tokenColors: tokens,
            backgroundColor: nsRaised
        )
    }

    private var nsCanvas: NSColor {
        self == .dark ? Self.rgb(30, 30, 30) : Self.rgb(255, 255, 255)
    }

    private var nsSidebar: NSColor {
        self == .dark ? Self.rgb(24, 24, 24) : Self.rgb(246, 246, 247)
    }

    private var nsRaised: NSColor {
        self == .dark ? Self.rgb(42, 42, 42) : Self.rgb(240, 240, 241)
    }

    private var nsText: NSColor {
        self == .dark ? Self.rgb(218, 218, 218) : Self.rgb(38, 40, 43)
    }

    private var nsEmphasis: NSColor {
        self == .dark ? Self.rgb(240, 240, 240) : Self.rgb(16, 16, 16)
    }

    private var nsSecondary: NSColor {
        self == .dark ? Self.rgb(150, 150, 150) : Self.rgb(130, 132, 136)
    }

    private var nsAccent: NSColor {
        self == .dark ? Self.rgb(138, 111, 245) : Self.rgb(107, 82, 216)
    }

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
    static let defaultValue = AppTheme.dark
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

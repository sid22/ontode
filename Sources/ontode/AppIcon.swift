import AppKit

enum AppIcon {
    static func install() {
        NSApplication.shared.applicationIconImage = image
    }

    static var bundledImage: NSImage? {
        guard let url = iconURL else { return nil }
        return NSImage(contentsOf: url)
    }

    private static var image: NSImage {
        bundledImage ?? fallbackImage
    }

    private static var iconURL: URL? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png") {
            return url
        }
        let bundleName = "ontode_ontode.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
        ]
        for case let candidate? in candidates {
            if let bundle = Bundle(url: candidate),
               let url = bundle.url(forResource: "AppIcon", withExtension: "png") {
                return url
            }
        }
        return nil
    }

    private static var fallbackImage: NSImage {
        NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 44, dy: 44), xRadius: 100, yRadius: 100)
            let gradient = NSGradient(
                starting: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.30, alpha: 1),
                ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.16, alpha: 1)
            )
            gradient?.draw(in: path, angle: -90)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 190, weight: .bold),
                .foregroundColor: NSColor.white,
            ]
            let text = NSAttributedString(string: "md", attributes: attributes)
            let textSize = text.size()
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
            return true
        }
    }
}

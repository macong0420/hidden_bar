import AppKit

enum ControlItemIconFactory {
    static func toggleImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        return NSImage(systemSymbolName: "chevron.left.2", accessibilityDescription: "Show hidden menu bar icons")?
            .withSymbolConfiguration(configuration)
            ?? fallbackImage()
    }

    static func separatorImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
        return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Hidden boundary")?
            .withSymbolConfiguration(configuration)
            ?? fallbackImage()
    }

    private static func fallbackImage() -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.labelColor.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

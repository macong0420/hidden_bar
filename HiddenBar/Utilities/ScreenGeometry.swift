import AppKit

enum ScreenGeometry {
    static let menuBarHeight: CGFloat = 24

    static func screenContaining(point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    static func notchRect(for screen: NSScreen) -> CGRect? {
        let auxLeft = screen.auxiliaryTopLeftArea ?? .zero
        let auxRight = screen.auxiliaryTopRightArea ?? .zero
        guard auxLeft.width > 0 || auxRight.width > 0 else { return nil }

        let menuBarOriginY = screen.frame.maxY - menuBarHeight
        let notchStartX = auxLeft.maxX
        let notchEndX = auxRight.minX
        guard notchEndX > notchStartX else { return nil }

        return CGRect(
            x: notchStartX,
            y: menuBarOriginY,
            width: notchEndX - notchStartX,
            height: menuBarHeight
        )
    }

    static func menuBarFrame(for screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )
    }

    static func cgPoint(fromScreen point: NSPoint, on screen: NSScreen) -> CGPoint {
        CGPoint(x: point.x, y: screen.frame.maxY - point.y)
    }

    static func cgRect(fromScreen rect: NSRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func screenRect(fromCGRect rect: CGRect, on screen: NSScreen) -> NSRect {
        NSRect(
            x: rect.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

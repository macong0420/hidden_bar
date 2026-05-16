import AppKit
import CoreGraphics

@MainActor
final class MenuBarItemEnumerator {
    private let ownPID: pid_t = ProcessInfo.processInfo.processIdentifier
    private let statusLayer = Int(CGWindowLevelForKey(.statusWindow))

    func currentItems(on screen: NSScreen) -> [MenuBarItem] {
        let infoArray = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        let menuBarCGFrame = ScreenGeometry.cgRect(
            fromScreen: ScreenGeometry.menuBarFrame(for: screen),
            on: screen
        )

        return infoArray
            .compactMap { dict -> MenuBarItem? in self.parseItem(from: dict, menuBar: menuBarCGFrame) }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    func itemsBetween(leftEdge: CGFloat, rightEdge: CGFloat, on screen: NSScreen) -> [MenuBarItem] {
        let items = currentItems(on: screen)
        let lower = min(leftEdge, rightEdge)
        let upper = max(leftEdge, rightEdge)
        return items.filter { $0.frame.midX > lower && $0.frame.midX < upper }
    }

    private func parseItem(from dict: [String: Any], menuBar: CGRect) -> MenuBarItem? {
        guard let layer = dict[kCGWindowLayer as String] as? Int,
              layer == statusLayer else { return nil }

        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let pid = dict[kCGWindowOwnerPID as String] as? Int32,
              pid != ownPID,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }

        let frame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        guard frame.intersects(menuBar) else { return nil }
        guard frame.width >= 6, frame.width <= 240 else { return nil }

        let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
        return MenuBarItem(windowID: windowID, processID: pid, ownerName: ownerName, frame: frame)
    }
}

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

        var metadata = MenuBarItemAXMetadataResolver.currentMetadata(excluding: ownPID)
        var items: [MenuBarItem] = []
        items.reserveCapacity(infoArray.count)

        for dict in infoArray {
            guard let item = parseItem(from: dict, menuBar: menuBarCGFrame, metadata: &metadata) else {
                continue
            }
            items.append(item)
        }

        return items.sorted { $0.frame.minX < $1.frame.minX }
    }

    private func parseItem(
        from dict: [String: Any],
        menuBar: CGRect,
        metadata: inout [MenuBarItemAXMetadata]
    ) -> MenuBarItem? {
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
        guard frame.width >= 6, frame.width <= 320 else { return nil }
        guard frame.height >= 16, frame.height <= 32 else { return nil }

        let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
        let title = dict[kCGWindowName as String] as? String

        if let title, title.hasPrefix("HiddenBar.") {
            return nil
        }

        let axMetadata = MenuBarItemAXMetadataResolver.matchMetadata(for: frame, in: &metadata)
        if axMetadata?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }

        let resolvedPID = axMetadata?.ownerPID ?? pid
        let runningApp = NSRunningApplication(processIdentifier: resolvedPID)
        let resolvedOwnerName = axMetadata?.ownerName ?? ownerName
        let resolvedBundleIdentifier = axMetadata?.bundleIdentifier ?? runningApp?.bundleIdentifier
        let resolvedTitle = axMetadata?.title ?? title
        let displayName = axMetadata?.displayName ?? Self.displayName(
            title: resolvedTitle,
            runningApp: runningApp,
            ownerName: resolvedOwnerName
        )

        return MenuBarItem(
            windowID: windowID,
            ownerPID: resolvedPID,
            ownerName: resolvedOwnerName,
            bundleIdentifier: resolvedBundleIdentifier,
            title: resolvedTitle,
            displayName: displayName,
            frame: frame
        )
    }

    private static func displayName(
        title: String?,
        runningApp: NSRunningApplication?,
        ownerName: String
    ) -> String {
        if let title, !title.isEmpty, !MenuBarItem.isGenericStatusItemTitle(title) {
            return title
        }

        if let localizedName = runningApp?.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        if let bundleURL = runningApp?.bundleURL,
           let bundle = Bundle(url: bundleURL) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !displayName.isEmpty {
                return displayName
            }
            if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !bundleName.isEmpty {
                return bundleName
            }
        }

        return ownerName
    }
}

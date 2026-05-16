import AppKit
import ApplicationServices

struct MenuBarItemAXMetadata {
    let ownerPID: pid_t
    let ownerName: String
    let bundleIdentifier: String?
    let title: String?
    let displayName: String
    let frame: CGRect
}

@MainActor
enum MenuBarItemAXMetadataResolver {
    private static let extrasMenuBarAttribute = "AXExtrasMenuBar"
    private static let messagingTimeout: Float = 0.04

    static func currentMetadata(excluding ownPID: pid_t) -> [MenuBarItemAXMetadata] {
        NSWorkspace.shared.runningApplications.flatMap { app -> [MenuBarItemAXMetadata] in
            guard app.processIdentifier != ownPID else { return [] }
            return metadata(for: app)
        }
    }

    static func matchMetadata(
        for frame: CGRect,
        in metadata: inout [MenuBarItemAXMetadata]
    ) -> MenuBarItemAXMetadata? {
        var bestIndex: Int?
        var bestScore = CGFloat.infinity

        for (index, candidate) in metadata.enumerated() {
            let score = matchScore(candidate.frame, frame)
            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        guard let bestIndex, bestScore < 48 else { return nil }
        return metadata.remove(at: bestIndex)
    }

    private static func metadata(for app: NSRunningApplication) -> [MenuBarItemAXMetadata] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, messagingTimeout)

        guard let extrasMenuBar: AXUIElement = copyAttribute(extrasMenuBarAttribute, from: axApp) else {
            return []
        }

        let children: [AXUIElement] = copyAttribute(kAXChildrenAttribute, from: extrasMenuBar) ?? []
        guard !children.isEmpty else { return [] }

        let ownerName = app.localizedName?.nonEmpty ?? app.bundleIdentifier ?? "Unknown"
        let displayName = displayName(for: app, fallback: ownerName)

        return children.compactMap { child in
            AXUIElementSetMessagingTimeout(child, messagingTimeout)
            guard let frame = frame(for: child), frame.width > 0, frame.height > 0 else {
                return nil
            }

            let title: String? = firstNonEmpty(
                copyAttribute(kAXTitleAttribute, from: child),
                copyAttribute(kAXDescriptionAttribute, from: child),
                copyAttribute(kAXHelpAttribute, from: child),
                copyAttribute(kAXIdentifierAttribute, from: child)
            )

            return MenuBarItemAXMetadata(
                ownerPID: app.processIdentifier,
                ownerName: ownerName,
                bundleIdentifier: app.bundleIdentifier,
                title: title,
                displayName: displayName,
                frame: frame
            )
        }
    }

    private static func displayName(for app: NSRunningApplication, fallback: String) -> String {
        if let localizedName = app.localizedName?.nonEmpty {
            return localizedName
        }

        if let bundleURL = app.bundleURL,
           let bundle = Bundle(url: bundleURL) {
            if let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.nonEmpty {
                return displayName
            }
            if let bundleName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?.nonEmpty {
                return bundleName
            }
        }

        return fallback
    }

    private static func frame(for element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = copyAttribute(kAXPositionAttribute, from: element),
              let sizeValue: AXValue = copyAttribute(kAXSizeAttribute, from: element) else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private static func matchScore(_ axFrame: CGRect, _ windowFrame: CGRect) -> CGFloat {
        let axMid = CGPoint(x: axFrame.midX, y: axFrame.midY)
        let windowMid = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let dx = abs(axMid.x - windowMid.x)
        let dy = abs(axMid.y - windowMid.y)

        let horizontalTolerance = max(18, (axFrame.width + windowFrame.width) / 2 + 8)
        let verticalTolerance = max(12, (axFrame.height + windowFrame.height) / 2 + 8)
        guard dx <= horizontalTolerance, dy <= verticalTolerance else {
            return .infinity
        }

        return dx + dy * 2
    }

    private static func copyAttribute<T>(_ attribute: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? T
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value = value?.nonEmpty {
                return value
            }
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

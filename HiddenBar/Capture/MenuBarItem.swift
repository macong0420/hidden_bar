import AppKit
import CoreGraphics

struct MenuBarItem: Hashable, Identifiable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let bundleIdentifier: String?
    let title: String?
    let displayName: String
    let frame: CGRect

    var id: CGWindowID { windowID }

    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    var canonicalIdentifier: String {
        if let bundleIdentifier, !bundleIdentifier.hasPrefix("com.apple.") {
            return bundleIdentifier
        }

        let namespace = bundleIdentifier ?? ownerName
        let titleComponent = (title?.isEmpty == false) ? title! : "<no-title>"
        if usesWindowScopedIdentifier(titleComponent: titleComponent) {
            return "\(namespace):\(titleComponent):window:\(windowID)"
        }
        return "\(namespace):\(titleComponent)"
    }

    var isMovable: Bool {
        if Self.immovableProcesses.contains(ownerName) { return false }
        if let bundleIdentifier, Self.immovableBundles.contains(bundleIdentifier) { return false }
        if Self.immovableTitles.contains(title ?? "") { return false }
        if let title, title.hasPrefix("com.apple.") { return false }
        if bundleIdentifier == Bundle.main.bundleIdentifier { return true }
        if let bundleIdentifier, !bundleIdentifier.hasPrefix("com.apple.") { return true }
        return Self.isGenericStatusItemTitle(title)
    }

    var isSystemMenuExtra: Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifier.hasPrefix("com.apple.") && bundleIdentifier != Bundle.main.bundleIdentifier
    }

    var logString: String {
        "\(displayName)#\(windowID)(pid:\(ownerPID))"
    }

    static let immovableProcesses: Set<String> = [
        "WindowServer",
        "WindowManager",
        "loginwindow"
    ]

    static let immovableBundles: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.Spotlight",
        "com.apple.TextInputMenuAgent",
        "com.apple.WindowManager"
    ]

    static let immovableTitles: Set<String> = [
        "Clock",
        "Siri",
        "BentoBox",
        "BentoBox-0",
        "NowPlaying",
        "AudioVideoModule",
        "MusicRecognition",
        "FaceTime",
        "Battery",
        "WiFi",
        "Spotlight",
        "AccessibilityShortcuts",
        "ScreenMirroring"
    ]

    static func isGenericStatusItemTitle(_ title: String?) -> Bool {
        guard let title, title.hasPrefix("Item-") else { return false }
        return title.dropFirst("Item-".count).allSatisfy(\.isNumber)
    }

    private func usesWindowScopedIdentifier(titleComponent: String) -> Bool {
        guard Self.isGenericStatusItemTitle(title) || titleComponent == "<no-title>" else {
            return false
        }

        guard let bundleIdentifier else { return true }
        return bundleIdentifier.hasPrefix("com.apple.")
    }
}

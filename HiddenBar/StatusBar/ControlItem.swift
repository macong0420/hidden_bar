import AppKit
import Combine

@MainActor
final class ControlItem {
    enum Identifier: String, CaseIterable {
        case main
        case divider

        var autosaveName: String { "HiddenBar.\(rawValue)" }

        var defaultPreferredPosition: CGFloat? {
            switch self {
            case .main: return 0
            case .divider: return 1
            }
        }

        var section: HiddenSection {
            switch self {
            case .main: return .visible
            case .divider: return .hidden
            }
        }
    }

    enum HidingState {
        case hideItems
        case showItems
    }

    enum Lengths {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
    }

    let identifier: Identifier

    @Published var state: HidingState = .hideItems

    var onPrimaryAction: (() -> Void)?
    var onSecondaryAction: (() -> Void)?

    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    var section: HiddenSection { identifier.section }

    var button: NSStatusBarButton? { statusItem.button }

    var window: NSWindow? { statusItem.button?.window }

    var windowFrame: CGRect? { window?.frame }

    var windowScreen: NSScreen? { window?.screen }

    private var cachedWindowID: CGWindowID?

    var windowID: CGWindowID? {
        if let cached = cachedWindowID, Bridging.getWindowFrame(for: cached) != nil {
            return cached
        }
        guard let window else { return nil }
        let number = window.windowNumber
        if number > 0, let id = CGWindowID(exactly: number), Bridging.getWindowFrame(for: id) != nil {
            cachedWindowID = id
            return id
        }
        if let resolved = resolveStatusItemWindowID() {
            cachedWindowID = resolved
            return resolved
        }
        return nil
    }

    private func resolveStatusItemWindowID() -> CGWindowID? {
        guard let buttonWindow = statusItem.button?.window else { return nil }
        guard let screen = buttonWindow.screen ?? NSScreen.main else { return nil }
        let nsFrame = buttonWindow.frame
        guard nsFrame.width > 0, nsFrame.height > 0 else { return nil }

        let expectedCG = ScreenGeometry.cgRect(fromScreen: nsFrame, on: screen)

        let menuBarIDs = Bridging.getWindowList(option: [.menuBarItems])
        var bestID: CGWindowID?
        var bestDelta: CGFloat = .infinity

        for id in menuBarIDs {
            guard let frame = Bridging.getWindowFrame(for: id) else { continue }
            let dx = abs(frame.minX - expectedCG.minX)
            if dx < bestDelta {
                bestDelta = dx
                bestID = id
            }
        }

        if let bestID, bestDelta < 6 {
            Logger.menuBar.debug("Resolved \(identifier.rawValue) windowID \(bestID) (dx=\(bestDelta))")
            return bestID
        }

        Logger.menuBar.warning(
            "Could not resolve \(identifier.rawValue) windowID; menuBarIDs=\(menuBarIDs.count) bestDelta=\(bestDelta) expectedX=\(expectedCG.minX)"
        )

        let ownPid = ProcessInfo.processInfo.processIdentifier
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        guard let info = CGWindowListCopyWindowInfo(
            [.optionAll],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        for dict in info {
            guard let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid == ownPid else { continue }
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == statusLayer else { continue }
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let bounds = dict[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let frame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            if abs(frame.minX - expectedCG.minX) < 8 {
                Logger.menuBar.debug("Resolved \(identifier.rawValue) via CGWindowList: id=\(id) frame=\(frame)")
                return id
            }
        }
        return nil
    }

    init(identifier: Identifier) {
        self.identifier = identifier

        let autosaveName = identifier.autosaveName
        if StatusItemDefaults[.preferredPosition, autosaveName] == nil,
           let position = identifier.defaultPreferredPosition {
            StatusItemDefaults[.preferredPosition, autosaveName] = position
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        self.statusItem = item

        configureButton()
        observeState()
        applyState()
    }

    deinit {
        let autosaveName = statusItem.autosaveName as String
        let cachedPosition = StatusItemDefaults[.preferredPosition, autosaveName]
        NSStatusBar.system.removeStatusItem(statusItem)
        StatusItemDefaults[.preferredPosition, autosaveName] = cachedPosition
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeState() {
        $state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyState() }
            .store(in: &cancellables)
    }

    private func applyState() {
        guard let button = statusItem.button else { return }

        switch identifier {
        case .main:
            statusItem.length = Lengths.standard
            button.cell?.isEnabled = true
            button.isHighlighted = false
            button.image = ControlItemIconFactory.toggleImage()
            button.image?.isTemplate = true
        case .divider:
            switch state {
            case .hideItems:
                statusItem.length = Lengths.expanded
                button.cell?.isEnabled = false
                button.isHighlighted = false
                button.image = nil
            case .showItems:
                statusItem.length = Lengths.standard
                button.cell?.isEnabled = true
                button.image = ControlItemIconFactory.separatorImage()
                button.image?.isTemplate = true
            }
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.option) == true {
            onSecondaryAction?()
        } else {
            onPrimaryAction?()
        }
    }
}

extension ControlItem {
    func asMenuBarItem(displayName: String) -> MenuBarItem? {
        guard let windowID else { return nil }
        let bundle = Bundle.main
        let ownerName = bundle.infoDictionary?["CFBundleName"] as? String ?? "HiddenBar"
        return MenuBarItem(
            windowID: windowID,
            ownerPID: ProcessInfo.processInfo.processIdentifier,
            ownerName: ownerName,
            bundleIdentifier: bundle.bundleIdentifier,
            title: displayName,
            displayName: displayName,
            frame: windowFrame ?? .zero
        )
    }
}

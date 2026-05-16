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

    var windowID: CGWindowID? {
        guard let window else { return nil }
        return CGWindowID(window.windowNumber)
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

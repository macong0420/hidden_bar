import AppKit
import Combine

@MainActor
final class MenuBarManager {
    var onToggle: (() -> Void)?
    var onShowPreferences: (() -> Void)?

    private(set) var visibleControl: ControlItem?
    private(set) var hiddenControl: ControlItem?

    private let settings: SettingsStore
    private let enumerator: MenuBarItemEnumerator

    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore, enumerator: MenuBarItemEnumerator) {
        self.settings = settings
        self.enumerator = enumerator
    }

    func install() {
        let visible = ControlItem(identifier: .main)
        let hidden = ControlItem(identifier: .divider)

        hidden.state = .hideItems

        visible.onPrimaryAction = { [weak self] in self?.onToggle?() }
        visible.onSecondaryAction = { [weak self] in self?.presentContextMenu() }
        hidden.onPrimaryAction = { [weak self] in self?.onToggle?() }
        hidden.onSecondaryAction = { [weak self] in self?.presentContextMenu() }

        self.visibleControl = visible
        self.hiddenControl = hidden
    }

    func uninstall() {
        cancellables.removeAll()
        visibleControl = nil
        hiddenControl = nil
    }

    func refreshLayout() {
        hiddenControl?.state = .hideItems
    }

    var toggleAnchorFrame: CGRect? {
        visibleControl?.windowFrame
    }

    var toggleAnchorScreen: NSScreen? {
        visibleControl?.windowScreen
    }

    func temporarilyRevealHiddenIcons(for duration: TimeInterval, then completion: @escaping () -> Void) {
        guard let hidden = hiddenControl else {
            completion()
            return
        }
        hidden.state = .showItems
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            completion()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                hidden.state = .hideItems
            }
        }
    }

    func revealAndSampleItems(then completion: @escaping ([MenuBarItem], NSScreen?) -> Void) {
        guard let hidden = hiddenControl, let screen = visibleControl?.windowScreen ?? NSScreen.main else {
            completion([], nil)
            return
        }
        hidden.state = .showItems
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else {
                hidden.state = .hideItems
                completion([], screen)
                return
            }
            let items = self.enumerator.currentItems(on: screen)
            hidden.state = .hideItems
            completion(items, screen)
        }
    }

    private func presentContextMenu() {
        let menu = NSMenu()
        let toggleItem = menu.addItem(withTitle: "Show / Hide Panel", action: #selector(menuToggle(_:)), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(.separator())
        let prefsItem = menu.addItem(withTitle: "Preferences…", action: #selector(menuPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit HiddenBar", action: #selector(menuQuit(_:)), keyEquivalent: "q")
        quitItem.target = self

        if let button = visibleControl?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
        }
    }

    @objc private func menuToggle(_ sender: Any?) {
        onToggle?()
    }

    @objc private func menuPreferences(_ sender: Any?) {
        onShowPreferences?()
    }

    @objc private func menuQuit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

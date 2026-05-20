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
    private var revealHoldCount = 0

    private static let clickRevealSettleDelay: TimeInterval = 0.16
    private static let revealSampleIntervals: [TimeInterval] = [0.12, 0.16, 0.24]
    private static let earlyStableSampleCount = 8

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
        visibleControl?.lastInteractionFrame ?? visibleControl?.windowFrame
    }

    var toggleAnchorScreen: NSScreen? {
        visibleControl?.lastInteractionScreen ?? visibleControl?.windowScreen
    }

    var visibleControlAsMenuBarItem: MenuBarItem? {
        visibleControl?.asMenuBarItem(displayName: "HiddenBar « Toggle")
    }

    var hiddenControlAsMenuBarItem: MenuBarItem? {
        hiddenControl?.asMenuBarItem(displayName: "HiddenBar Hidden Divider")
    }

    func temporarilyRevealHiddenIcons(for duration: TimeInterval, then completion: @escaping () -> Void) {
        guard let hidden = holdHiddenItemsRevealed() else {
            completion()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.clickRevealSettleDelay) { [weak self, hidden] in
            completion()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard let self else { return }
                self.releaseHiddenItemsReveal(hidden)
            }
        }
    }

    func revealAndSampleItems(then completion: @escaping ([MenuBarItem], NSScreen?) -> Void) {
        guard let screen = toggleAnchorScreen ?? NSScreen.main,
              let hidden = holdHiddenItemsRevealed() else {
            completion([], nil)
            return
        }
        sampleBestRevealedItems(on: screen) { [weak self, hidden] items in
            guard let self else {
                completion([], screen)
                return
            }
            Logger.menuBar.debug("Reveal sampling selected \(items.count) items on \(screen.localizedName)")
            completion(items, screen)
            self.releaseHiddenItemsReveal(hidden)
        }
    }

    func withHiddenItemsRevealed<T>(
        settleDelay: Duration = .milliseconds(0),
        operation: @MainActor ([MenuBarItem], NSScreen) async -> T
    ) async -> T? {
        guard let screen = toggleAnchorScreen ?? NSScreen.main,
              let hidden = holdHiddenItemsRevealed() else {
            return nil
        }

        defer { releaseHiddenItemsReveal(hidden) }

        do {
            try await Task.sleep(for: settleDelay)
        } catch {
            return nil
        }

        let items = await sampleBestRevealedItems(on: screen)
        return await operation(items, screen)
    }

    private func holdHiddenItemsRevealed() -> ControlItem? {
        guard let hidden = hiddenControl else { return nil }
        revealHoldCount += 1
        hidden.state = .showItems
        return hidden
    }

    private func releaseHiddenItemsReveal(_ hidden: ControlItem) {
        revealHoldCount = max(0, revealHoldCount - 1)
        guard revealHoldCount == 0 else { return }
        hidden.state = .hideItems
    }

    private func sampleBestRevealedItems(on screen: NSScreen) async -> [MenuBarItem] {
        await withCheckedContinuation { continuation in
            sampleBestRevealedItems(on: screen) { items in
                continuation.resume(returning: items)
            }
        }
    }

    private func sampleBestRevealedItems(
        on screen: NSScreen,
        intervals: ArraySlice<TimeInterval>? = nil,
        bestItems: [MenuBarItem] = [],
        completion: @escaping ([MenuBarItem]) -> Void
    ) {
        let activeIntervals = intervals ?? ArraySlice(Self.revealSampleIntervals)
        guard let interval = activeIntervals.first else {
            completion(bestItems)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self else {
                completion(bestItems)
                return
            }

            let currentItems = self.enumerator.currentItemsAcrossScreens(preferredScreen: screen)
            let nextBestItems = currentItems.count >= bestItems.count ? currentItems : bestItems
            let remainingIntervals = activeIntervals.dropFirst()

            Logger.menuBar.debug(
                "Reveal sampling pass: current=\(currentItems.count) best=\(nextBestItems.count) screen=\(screen.localizedName)"
            )

            if currentItems.count == bestItems.count,
               currentItems.count >= Self.earlyStableSampleCount {
                completion(nextBestItems)
                return
            }

            self.sampleBestRevealedItems(
                on: screen,
                intervals: remainingIntervals,
                bestItems: nextBestItems,
                completion: completion
            )
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

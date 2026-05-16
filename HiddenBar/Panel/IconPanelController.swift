import AppKit
import Combine
import CoreGraphics

@MainActor
struct PanelAnchor {
    let frame: CGRect
    let screen: NSScreen
}

@MainActor
final class IconPanelController {
    typealias AnchorProvider = () -> PanelAnchor?
    typealias ClickForwarder = (CGPoint) -> Void
    typealias ItemsSampler = (@escaping ([MenuBarItem], NSScreen?) -> Void) -> Void

    var anchorProvider: AnchorProvider?
    var clickForwarder: ClickForwarder?
    var itemsSampler: ItemsSampler?

    private let settings: SettingsStore
    private let capture: MenuBarItemImageCapture
    private let forwarder: MouseEventForwarder
    private let panel: IconBarPanel

    private static let systemMenuBarProcesses: Set<String> = [
        "SystemUIServer",
        "ControlCenter",
        "WindowManager",
        "WindowServer",
        "TextInputMenuAgent",
        "TextInputSwitcher",
        "Spotlight",
        "Siri",
        "NotificationCenter",
        "Notification Center",
        "loginwindow",
        "AccessibilityVisualsAgent"
    ]

    private var autoHideWorkItem: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: SettingsStore,
        capture: MenuBarItemImageCapture,
        forwarder: MouseEventForwarder
    ) {
        self.settings = settings
        self.capture = capture
        self.forwarder = forwarder
        self.panel = IconBarPanel()
        self.panel.iconBarView.cellDelegate = self

        settings.$preferences
            .removeDuplicates()
            .sink { [weak self] _ in self?.refreshLayoutIfVisible() }
            .store(in: &cancellables)
    }

    func toggle() {
        if panel.isVisible {
            dismiss(animated: true)
        } else {
            present()
        }
    }

    func present() {
        guard let anchor = anchorProvider?() else {
            Logger.panel.notice("No anchor available; cannot present panel.")
            return
        }

        let sampler = itemsSampler ?? { completion in completion([], anchor.screen) }
        sampler { [weak self] allItems, screen in
            guard let self else { return }
            let targetScreen = screen ?? anchor.screen
            let items = self.filterDisplayableItems(allItems: allItems, anchor: anchor)
            self.renderPanel(items: items, anchor: anchor, screen: targetScreen)
        }
    }

    func dismiss(animated: Bool) {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
        if panel.isVisible {
            panel.orderOut(nil)
        }
        panel.iconBarView.clear()
    }

    func dismissIfClickedOutside() {
        guard panel.isVisible else { return }
        let location = NSEvent.mouseLocation
        if !panel.frame.insetBy(dx: -1, dy: -1).contains(location) {
            dismiss(animated: true)
        }
    }

    func refreshLayout() {
        refreshLayoutIfVisible()
    }

    private func renderPanel(items: [MenuBarItem], anchor: PanelAnchor, screen: NSScreen) {
        guard !items.isEmpty else {
            Logger.panel.debug("No items to display in panel.")
            dismiss(animated: false)
            return
        }

        guard let layout = ScreenLayoutCalculator.layout(
            items: items,
            anchor: anchor.frame,
            screen: screen,
            preferences: settings.preferences
        ) else {
            return
        }

        let allowlist = settings.preferences.alwaysVisibleApps
        panel.apply(layout: layout)
        panel.iconBarView.render(layout: layout, images: [:], allowlist: allowlist)
        panel.orderFrontRegardless()

        Task { [weak self] in
            guard let self else { return }
            let images = await self.capture.captureImages(for: items)
            guard self.panel.isVisible else { return }
            self.panel.iconBarView.render(
                layout: layout,
                images: images,
                allowlist: self.settings.preferences.alwaysVisibleApps
            )
        }

        scheduleAutoHide()
    }

    private func refreshLayoutIfVisible() {
        guard panel.isVisible else { return }
        present()
    }

    private func scheduleAutoHide() {
        autoHideWorkItem?.cancel()
        guard settings.preferences.autoHideEnabled else { return }
        let delay = settings.preferences.autoHideDelay
        let work = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
        autoHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func filterDisplayableItems(allItems: [MenuBarItem], anchor: PanelAnchor) -> [MenuBarItem] {
        let anchorCG = ScreenGeometry.cgRect(fromScreen: anchor.frame, on: anchor.screen)
        return allItems
            .filter { item in
                !item.isSystemMenuExtra &&
                !Self.systemMenuBarProcesses.contains(item.ownerName) &&
                item.frame.midX < anchorCG.minX
            }
            .sorted { $0.frame.minX > $1.frame.minX }
    }
}

extension IconPanelController: MenuBarItemCellDelegate {
    func cellWasClicked(_ cell: MenuBarItemCell) {
        let target = CGPoint(x: cell.item.frame.midX, y: cell.item.frame.midY)
        dismiss(animated: false)

        if let forwarder = clickForwarder {
            forwarder(target)
        } else {
            forwarder.forwardClick(at: target)
        }
    }

    func cellRequestsAllowlistToggle(_ cell: MenuBarItemCell) {
        let identifier = cell.item.canonicalIdentifier
        let willBeAllowlisted = !settings.preferences.alwaysVisibleApps.contains(identifier)
        settings.update {
            if willBeAllowlisted {
                $0.alwaysVisibleApps.insert(identifier)
            } else {
                $0.alwaysVisibleApps.remove(identifier)
            }
        }
        cell.updateAllowlistBadge(isAllowlisted: willBeAllowlisted)
    }

    func cellIsInAllowlist(_ cell: MenuBarItemCell) -> Bool {
        settings.preferences.alwaysVisibleApps.contains(cell.item.canonicalIdentifier)
    }
}

import AppKit
import Combine

@MainActor
final class AllowlistSyncCoordinator {
    typealias ItemsSampler = (@escaping ([MenuBarItem], NSScreen?) -> Void) -> Void

    private weak var menuBarManager: MenuBarManager?
    private let settings: SettingsStore
    private let mover: MenuBarItemMover

    var itemsSampler: ItemsSampler?

    private var cancellables: Set<AnyCancellable> = []
    private var debouncer: DispatchWorkItem?
    private var inflight: Task<Void, Never>?
    private var retryAttempt: Int = 0
    private var lastAllowlist: Set<String> = []
    private var pendingRemovedIdentifiers: Set<String> = []
    private static let maxRetryAttempts = 6

    init(
        menuBarManager: MenuBarManager,
        settings: SettingsStore,
        mover: MenuBarItemMover
    ) {
        self.menuBarManager = menuBarManager
        self.settings = settings
        self.mover = mover
    }

    func start() {
        lastAllowlist = settings.preferences.alwaysVisibleApps

        settings.$preferences
            .map(\.alwaysVisibleApps)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] allowlist in
                self?.handleAllowlistChange(allowlist)
            }
            .store(in: &cancellables)

        let center = NSWorkspace.shared.notificationCenter
        Publishers.Merge(
            center.publisher(for: NSWorkspace.didLaunchApplicationNotification),
            center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
        )
        .sink { [weak self] _ in self?.scheduleSync() }
        .store(in: &cancellables)

        scheduleSync(delay: 2.5)
    }

    func stop() {
        cancellables.removeAll()
        debouncer?.cancel()
        inflight?.cancel()
    }

    func syncNow() {
        scheduleSync(delay: 0)
    }

    private func scheduleSync(delay: TimeInterval = 0.5) {
        debouncer?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performSync() }
        debouncer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleAllowlistChange(_ allowlist: Set<String>) {
        pendingRemovedIdentifiers.formUnion(lastAllowlist.subtracting(allowlist))
        lastAllowlist = allowlist
        scheduleSync(delay: 0)
    }

    private func performSync() {
        guard let manager = menuBarManager else { return }

        guard let hiddenAnchor = manager.hiddenControlAsMenuBarItem else {
            retryAttempt += 1
            if retryAttempt <= Self.maxRetryAttempts {
                let delay = min(0.5 * Double(retryAttempt), 3.0)
                Logger.events.debug("Allowlist anchor not ready, retry \(retryAttempt) in \(delay)s")
                scheduleSync(delay: delay)
            } else {
                Logger.events.notice("Allowlist sync giving up after \(Self.maxRetryAttempts) retries; control items unavailable.")
                retryAttempt = 0
            }
            return
        }
        retryAttempt = 0

        let allowlist = settings.preferences.alwaysVisibleApps
        let syncableIdentifiers = allowlist.union(pendingRemovedIdentifiers)
        pendingRemovedIdentifiers.removeAll()

        inflight?.cancel()
        inflight = Task { [weak self, weak manager] in
            guard let self, let manager else { return }
            _ = await manager.withHiddenItemsRevealed { items, _ in
                await self.sync(
                    items: items,
                    hiddenAnchor: hiddenAnchor,
                    allowlist: allowlist,
                    syncableIdentifiers: syncableIdentifiers
                )
            }
        }
    }

    private func sync(
        items: [MenuBarItem],
        hiddenAnchor: MenuBarItem,
        allowlist: Set<String>,
        syncableIdentifiers: Set<String>
    ) async {
        guard let hiddenFrame = Bridging.getWindowFrame(for: hiddenAnchor.windowID) else {
            Logger.events.error("Allowlist sync: cannot read hidden anchor frame")
            return
        }

        let movableItems = items.filter { $0.isMovable }
        var toPin: [MenuBarItem] = []
        var toUnpin: [MenuBarItem] = []

        for item in movableItems {
            let identifier = item.canonicalIdentifier
            guard syncableIdentifiers.contains(identifier) else { continue }

            let currentlyVisible = item.frame.minX >= hiddenFrame.maxX - 1
            let shouldBeVisible = allowlist.contains(identifier)
            if shouldBeVisible && !currentlyVisible {
                toPin.append(item)
            } else if !shouldBeVisible && currentlyVisible {
                toUnpin.append(item)
            }
        }

        Logger.events.debug("Allowlist sync: sampled \(items.count) items, toPin=\(toPin.count) toUnpin=\(toUnpin.count)")
        guard !(toPin.isEmpty && toUnpin.isEmpty) else { return }

        for target in toUnpin {
            if Task.isCancelled { return }
            do {
                try await mover.move(item: target, to: .leftOfItem(hiddenAnchor))
                Logger.events.info("Allowlist: unpinned \(target.logString) (moved left of divider)")
            } catch {
                Logger.events.error("Allowlist unpin failed for \(target.logString): \(error.localizedDescription)")
            }
        }

        for target in toPin {
            if Task.isCancelled { return }
            do {
                try await mover.move(item: target, to: .rightOfItem(hiddenAnchor))
                Logger.events.info("Allowlist: pinned \(target.logString) (moved right of divider)")
            } catch {
                Logger.events.error("Allowlist pin failed for \(target.logString): \(error.localizedDescription)")
            }
        }
    }
}

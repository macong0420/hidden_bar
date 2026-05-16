import AppKit
import Combine

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    let permissions: PermissionsManager
    let menuBarManager: MenuBarManager
    let panelController: IconPanelController
    let mouseForwarder: MouseEventForwarder
    let launchAtLogin: LaunchAtLoginManager

    private var cancellables: Set<AnyCancellable> = []
    private var globalClickMonitor: GlobalEventMonitor?
    private var settingsWindowController: SettingsWindowController?

    init() {
        let settings = SettingsStore()
        let permissions = PermissionsManager()
        let enumerator = MenuBarItemEnumerator()
        let capture = MenuBarItemImageCapture()
        let forwarder = MouseEventForwarder()
        let launchAtLogin = LaunchAtLoginManager()

        let menuBarManager = MenuBarManager(settings: settings, enumerator: enumerator)
        let panelController = IconPanelController(
            settings: settings,
            capture: capture,
            forwarder: forwarder
        )

        self.settings = settings
        self.permissions = permissions
        self.menuBarManager = menuBarManager
        self.panelController = panelController
        self.mouseForwarder = forwarder
        self.launchAtLogin = launchAtLogin
    }

    func start() {
        menuBarManager.install()
        permissions.bootstrap()

        menuBarManager.onToggle = { [weak self] in
            self?.panelController.toggle()
        }
        menuBarManager.onShowPreferences = { [weak self] in
            self?.showPreferences()
        }

        panelController.anchorProvider = { [weak self] in
            guard let self,
                  let frame = self.menuBarManager.toggleAnchorFrame,
                  let screen = self.menuBarManager.toggleAnchorScreen else {
                return nil
            }
            return PanelAnchor(frame: frame, screen: screen)
        }

        panelController.itemsSampler = { [weak self] completion in
            guard let self else {
                completion([], nil)
                return
            }
            self.menuBarManager.revealAndSampleItems(then: completion)
        }

        panelController.clickForwarder = { [weak self] point in
            guard let self else { return }
            self.menuBarManager.temporarilyRevealHiddenIcons(for: 0.3) {
                self.mouseForwarder.forwardClick(at: point)
            }
        }

        let monitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.panelController.dismissIfClickedOutside()
        }
        monitor.start()
        globalClickMonitor = monitor

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.menuBarManager.refreshLayout()
                self?.panelController.refreshLayout()
            }
            .store(in: &cancellables)
    }

    func stop() {
        globalClickMonitor?.stop()
        globalClickMonitor = nil
        cancellables.removeAll()
        panelController.dismiss(animated: false)
        menuBarManager.uninstall()
    }

    private func showPreferences() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settings: settings,
                launchAtLogin: launchAtLogin
            )
        }
        settingsWindowController?.present()
    }
}

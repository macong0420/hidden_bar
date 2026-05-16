import AppKit

@MainActor
final class IconBarPanel: NSPanel {
    let iconBarView: IconBarView
    private let backgroundView: NSVisualEffectView

    init() {
        let panelStyle: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let frame = NSRect(x: 0, y: 0, width: 200, height: 40)

        let background = NSVisualEffectView(frame: frame)
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let iconBar = IconBarView(frame: frame)
        iconBar.autoresizingMask = [.width, .height]
        background.addSubview(iconBar)

        self.backgroundView = background
        self.iconBarView = iconBar

        super.init(
            contentRect: frame,
            styleMask: panelStyle,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        worksWhenModal = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .utilityWindow
        becomesKeyOnlyIfNeeded = true

        contentView = background

        let panelFrame = self.frame
        iconBar.frame = NSRect(origin: .zero, size: panelFrame.size)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func apply(layout: PanelLayout) {
        setFrame(layout.panelFrame, display: true, animate: false)
        backgroundView.frame = NSRect(origin: .zero, size: layout.panelFrame.size)
        iconBarView.frame = backgroundView.bounds
    }
}

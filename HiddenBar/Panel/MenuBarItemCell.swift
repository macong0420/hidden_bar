import AppKit
import CoreGraphics

@MainActor
protocol MenuBarItemCellDelegate: AnyObject {
    func cellWasClicked(_ cell: MenuBarItemCell)
    func cellRequestsAllowlistToggle(_ cell: MenuBarItemCell)
    func cellIsInAllowlist(_ cell: MenuBarItemCell) -> Bool
}

@MainActor
final class MenuBarItemCell: NSView {
    let item: MenuBarItem
    weak var delegate: MenuBarItemCellDelegate?

    private let imageView: NSImageView
    private let hoverBackground: NSView
    private let pinBadge: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { hoverBackground.layer?.opacity = isHovering ? 1 : 0 }
    }

    init(item: MenuBarItem) {
        self.item = item
        self.imageView = NSImageView()
        self.hoverBackground = NSView()
        self.pinBadge = NSImageView()
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateImage(_ cgImage: CGImage?) {
        guard let cgImage else {
            imageView.image = placeholderImage()
            return
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let size = NSSize(
            width: CGFloat(cgImage.width) / max(1, scale),
            height: CGFloat(cgImage.height) / max(1, scale)
        )
        imageView.image = NSImage(cgImage: cgImage, size: size)
    }

    func updateAllowlistBadge(isAllowlisted: Bool) {
        pinBadge.isHidden = !isAllowlisted
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent) { isHovering = false }

    override func mouseDown(with event: NSEvent) {
        delegate?.cellWasClicked(self)
    }

    override func rightMouseDown(with event: NSEvent) {
        let isAllowlisted = delegate?.cellIsInAllowlist(self) ?? false
        let menu = NSMenu()
        let title = isAllowlisted
            ? "Remove from “Always Show”"
            : "Always show in menu bar"
        let toggle = NSMenuItem(title: title, action: #selector(toggleAllowlistAction), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    @objc private func toggleAllowlistAction() {
        delegate?.cellRequestsAllowlistToggle(self)
    }

    private func setupSubviews() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        hoverBackground.translatesAutoresizingMaskIntoConstraints = false
        hoverBackground.wantsLayer = true
        hoverBackground.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        hoverBackground.layer?.cornerRadius = 6
        hoverBackground.layer?.opacity = 0
        addSubview(hoverBackground)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.image = placeholderImage()
        addSubview(imageView)

        pinBadge.translatesAutoresizingMaskIntoConstraints = false
        let configuration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        pinBadge.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Always visible")?
            .withSymbolConfiguration(configuration)
        pinBadge.contentTintColor = .controlAccentColor
        pinBadge.isHidden = true
        addSubview(pinBadge)

        NSLayoutConstraint.activate([
            hoverBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            hoverBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            hoverBackground.topAnchor.constraint(equalTo: topAnchor),
            hoverBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, constant: -4),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, constant: -4),

            pinBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            pinBadge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pinBadge.widthAnchor.constraint(equalToConstant: 10),
            pinBadge.heightAnchor.constraint(equalToConstant: 10)
        ])

        toolTip = item.displayName.isEmpty ? item.ownerName : item.displayName
    }

    private func placeholderImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: "square.dashed", accessibilityDescription: item.ownerName)?
            .withSymbolConfiguration(configuration)
            ?? NSImage()
    }
}

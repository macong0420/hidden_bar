import AppKit
import CoreGraphics

@MainActor
protocol MenuBarItemCellDelegate: AnyObject {
    func cellWasClicked(_ cell: MenuBarItemCell)
}

@MainActor
final class MenuBarItemCell: NSView {
    let item: MenuBarItem
    weak var delegate: MenuBarItemCellDelegate?

    private let imageView: NSImageView
    private let hoverBackground: NSView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { hoverBackground.layer?.opacity = isHovering ? 1 : 0 }
    }

    init(item: MenuBarItem) {
        self.item = item
        self.imageView = NSImageView()
        self.hoverBackground = NSView()
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
        let size = NSSize(
            width: CGFloat(cgImage.width) / max(1, NSScreen.main?.backingScaleFactor ?? 2),
            height: CGFloat(cgImage.height) / max(1, NSScreen.main?.backingScaleFactor ?? 2)
        )
        imageView.image = NSImage(cgImage: cgImage, size: size)
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

        NSLayoutConstraint.activate([
            hoverBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            hoverBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            hoverBackground.topAnchor.constraint(equalTo: topAnchor),
            hoverBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, constant: -4),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, constant: -4)
        ])

        toolTip = item.ownerName.isEmpty ? "Menu bar item" : item.ownerName
    }

    private func placeholderImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: "square.dashed", accessibilityDescription: item.ownerName)?
            .withSymbolConfiguration(configuration)
            ?? NSImage()
    }
}

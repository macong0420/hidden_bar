import AppKit

@MainActor
final class IconBarView: NSView {
    weak var cellDelegate: MenuBarItemCellDelegate?

    private(set) var cells: [CGWindowID: MenuBarItemCell] = [:]

    override var isFlipped: Bool { false }

    func render(layout: PanelLayout, images: [CGWindowID: CGImage], allowlist: Set<String>) {
        var newCells: [CGWindowID: MenuBarItemCell] = [:]
        let layoutIDs = Set(layout.placements.map { $0.item.windowID })

        for (id, cell) in cells where !layoutIDs.contains(id) {
            cell.removeFromSuperview()
        }

        for placement in layout.placements {
            let cell: MenuBarItemCell
            if let existing = cells[placement.item.windowID] {
                cell = existing
            } else {
                cell = MenuBarItemCell(item: placement.item)
                cell.delegate = cellDelegate
                addSubview(cell)
            }
            cell.frame = placement.frameInPanel
            cell.updateImage(images[placement.item.windowID])
            cell.updateAllowlistBadge(
                isAllowlisted: placement.item.isMovable && allowlist.contains(placement.item.canonicalIdentifier)
            )
            newCells[placement.item.windowID] = cell
        }

        cells = newCells
    }

    func clear() {
        for cell in cells.values {
            cell.removeFromSuperview()
        }
        cells.removeAll()
    }
}

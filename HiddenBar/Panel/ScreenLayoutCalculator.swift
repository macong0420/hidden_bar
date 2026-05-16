import AppKit
import CoreGraphics

struct PanelLayout: Equatable {
    struct Placement: Equatable {
        let item: MenuBarItem
        let frameInPanel: NSRect
    }

    let panelFrame: NSRect
    let placements: [Placement]
}

enum ScreenLayoutCalculator {
    static func layout(
        items: [MenuBarItem],
        anchor: CGRect,
        screen: NSScreen,
        preferences: AppPreferences
    ) -> PanelLayout? {
        guard !items.isEmpty else { return nil }

        let cellSize = preferences.itemSize
        let spacing = preferences.itemSpacing
        let rowSpacing = preferences.rowSpacing
        let padding = preferences.panelPadding
        let maxItemsPerRow = max(1, preferences.maxItemsPerRow)

        let itemCount = items.count
        let widestRowCount = min(maxItemsPerRow, itemCount)

        let availableWidth = max(80, screen.visibleFrame.width - 2 * padding)
        let widthLimitItems = max(1, Int(floor((availableWidth - spacing) / (cellSize + spacing))))
        let columnsPerRow = min(widestRowCount, widthLimitItems)
        let adjustedRowCount = Int(ceil(Double(itemCount) / Double(columnsPerRow)))

        let contentWidth = CGFloat(columnsPerRow) * cellSize + CGFloat(max(0, columnsPerRow - 1)) * spacing
        let contentHeight = CGFloat(adjustedRowCount) * cellSize + CGFloat(max(0, adjustedRowCount - 1)) * rowSpacing
        let panelWidth = contentWidth + 2 * padding
        let panelHeight = contentHeight + 2 * padding

        let originX = panelOriginX(
            anchor: anchor,
            screen: screen,
            panelWidth: panelWidth,
            preferences: preferences
        )
        let originY = panelOriginY(
            anchor: anchor,
            screen: screen,
            panelHeight: panelHeight,
            preferences: preferences
        )

        var panelFrame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
        panelFrame = avoidNotch(panelFrame: panelFrame, screen: screen, preferences: preferences)

        let placements = placeCells(
            items: items,
            columnsPerRow: columnsPerRow,
            cellSize: cellSize,
            spacing: spacing,
            rowSpacing: rowSpacing,
            padding: padding,
            panelWidth: panelWidth,
            panelHeight: panelHeight
        )

        return PanelLayout(panelFrame: panelFrame, placements: placements)
    }

    private static func panelOriginX(
        anchor: CGRect,
        screen: NSScreen,
        panelWidth: CGFloat,
        preferences: AppPreferences
    ) -> CGFloat {
        let preferredRightEdge: CGFloat
        switch preferences.panelAnchor {
        case .belowToggle:
            preferredRightEdge = anchor.maxX + preferences.panelHorizontalOffset
        case .belowRightEdge:
            preferredRightEdge = screen.frame.maxX + preferences.panelHorizontalOffset
        case .custom:
            preferredRightEdge = anchor.maxX + preferences.panelHorizontalOffset
        }

        let minX = screen.frame.minX + 4
        let maxX = screen.frame.maxX - 4
        let proposed = preferredRightEdge - panelWidth
        return max(minX, min(proposed, maxX - panelWidth))
    }

    private static func panelOriginY(
        anchor: CGRect,
        screen: NSScreen,
        panelHeight: CGFloat,
        preferences: AppPreferences
    ) -> CGFloat {
        let menuBarBottom = screen.frame.maxY - ScreenGeometry.menuBarHeight
        return menuBarBottom - panelHeight - preferences.panelVerticalOffset
    }

    private static func avoidNotch(
        panelFrame: NSRect,
        screen: NSScreen,
        preferences: AppPreferences
    ) -> NSRect {
        guard preferences.avoidNotch,
              let notchCG = ScreenGeometry.notchRect(for: screen) else {
            return panelFrame
        }
        let notchNS = ScreenGeometry.screenRect(fromCGRect: notchCG, on: screen)
        guard notchNS.intersects(panelFrame) else { return panelFrame }
        var adjusted = panelFrame
        adjusted.origin.y = notchNS.minY - panelFrame.height - 2
        return adjusted
    }

    private static func placeCells(
        items: [MenuBarItem],
        columnsPerRow: Int,
        cellSize: CGFloat,
        spacing: CGFloat,
        rowSpacing: CGFloat,
        padding: CGFloat,
        panelWidth: CGFloat,
        panelHeight: CGFloat
    ) -> [PanelLayout.Placement] {
        var placements: [PanelLayout.Placement] = []
        placements.reserveCapacity(items.count)

        for (index, item) in items.enumerated() {
            let row = index / columnsPerRow
            let column = index % columnsPerRow
            let xFromRight = CGFloat(column) * (cellSize + spacing)
            let yFromTop = CGFloat(row) * (cellSize + rowSpacing)

            let cellOriginX = panelWidth - padding - cellSize - xFromRight
            let cellOriginY = panelHeight - padding - cellSize - yFromTop
            let frame = NSRect(x: cellOriginX, y: cellOriginY, width: cellSize, height: cellSize)
            placements.append(PanelLayout.Placement(item: item, frameInPanel: frame))
        }

        return placements
    }
}

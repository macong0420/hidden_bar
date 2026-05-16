import AppKit
import Foundation

enum PanelAnchorMode: String, Codable, CaseIterable {
    case belowToggle
    case belowRightEdge
    case custom
}

struct AppPreferences: Codable, Equatable {
    var autoHideEnabled: Bool
    var autoHideDelay: TimeInterval
    var panelAnchor: PanelAnchorMode
    var panelHorizontalOffset: CGFloat
    var panelVerticalOffset: CGFloat
    var maxItemsPerRow: Int
    var avoidNotch: Bool
    var itemSize: CGFloat
    var itemSpacing: CGFloat
    var rowSpacing: CGFloat
    var panelPadding: CGFloat
    var rememberHiddenStateAcrossLaunches: Bool

    static let `default` = AppPreferences(
        autoHideEnabled: true,
        autoHideDelay: 5,
        panelAnchor: .belowRightEdge,
        panelHorizontalOffset: -8,
        panelVerticalOffset: 6,
        maxItemsPerRow: 8,
        avoidNotch: true,
        itemSize: 36,
        itemSpacing: 8,
        rowSpacing: 6,
        panelPadding: 10,
        rememberHiddenStateAcrossLaunches: true
    )
}

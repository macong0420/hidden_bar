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
    var alwaysVisibleApps: Set<String>

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
        rememberHiddenStateAcrossLaunches: true,
        alwaysVisibleApps: []
    )

    enum CodingKeys: String, CodingKey {
        case autoHideEnabled
        case autoHideDelay
        case panelAnchor
        case panelHorizontalOffset
        case panelVerticalOffset
        case maxItemsPerRow
        case avoidNotch
        case itemSize
        case itemSpacing
        case rowSpacing
        case panelPadding
        case rememberHiddenStateAcrossLaunches
        case alwaysVisibleApps
    }

    init(
        autoHideEnabled: Bool,
        autoHideDelay: TimeInterval,
        panelAnchor: PanelAnchorMode,
        panelHorizontalOffset: CGFloat,
        panelVerticalOffset: CGFloat,
        maxItemsPerRow: Int,
        avoidNotch: Bool,
        itemSize: CGFloat,
        itemSpacing: CGFloat,
        rowSpacing: CGFloat,
        panelPadding: CGFloat,
        rememberHiddenStateAcrossLaunches: Bool,
        alwaysVisibleApps: Set<String>
    ) {
        self.autoHideEnabled = autoHideEnabled
        self.autoHideDelay = autoHideDelay
        self.panelAnchor = panelAnchor
        self.panelHorizontalOffset = panelHorizontalOffset
        self.panelVerticalOffset = panelVerticalOffset
        self.maxItemsPerRow = maxItemsPerRow
        self.avoidNotch = avoidNotch
        self.itemSize = itemSize
        self.itemSpacing = itemSpacing
        self.rowSpacing = rowSpacing
        self.panelPadding = panelPadding
        self.rememberHiddenStateAcrossLaunches = rememberHiddenStateAcrossLaunches
        self.alwaysVisibleApps = alwaysVisibleApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppPreferences.default
        self.autoHideEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoHideEnabled) ?? fallback.autoHideEnabled
        self.autoHideDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .autoHideDelay) ?? fallback.autoHideDelay
        self.panelAnchor = try container.decodeIfPresent(PanelAnchorMode.self, forKey: .panelAnchor) ?? fallback.panelAnchor
        self.panelHorizontalOffset = try container.decodeIfPresent(CGFloat.self, forKey: .panelHorizontalOffset) ?? fallback.panelHorizontalOffset
        self.panelVerticalOffset = try container.decodeIfPresent(CGFloat.self, forKey: .panelVerticalOffset) ?? fallback.panelVerticalOffset
        self.maxItemsPerRow = try container.decodeIfPresent(Int.self, forKey: .maxItemsPerRow) ?? fallback.maxItemsPerRow
        self.avoidNotch = try container.decodeIfPresent(Bool.self, forKey: .avoidNotch) ?? fallback.avoidNotch
        self.itemSize = try container.decodeIfPresent(CGFloat.self, forKey: .itemSize) ?? fallback.itemSize
        self.itemSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .itemSpacing) ?? fallback.itemSpacing
        self.rowSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .rowSpacing) ?? fallback.rowSpacing
        self.panelPadding = try container.decodeIfPresent(CGFloat.self, forKey: .panelPadding) ?? fallback.panelPadding
        self.rememberHiddenStateAcrossLaunches = try container.decodeIfPresent(Bool.self, forKey: .rememberHiddenStateAcrossLaunches) ?? fallback.rememberHiddenStateAcrossLaunches
        self.alwaysVisibleApps = try container.decodeIfPresent(Set<String>.self, forKey: .alwaysVisibleApps) ?? fallback.alwaysVisibleApps
    }
}

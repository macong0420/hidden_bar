import Foundation

enum HiddenSection: Int, CaseIterable, Codable {
    case visible
    case hidden

    var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .hidden: return "Hidden"
        }
    }
}

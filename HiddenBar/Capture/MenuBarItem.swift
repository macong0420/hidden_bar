import CoreGraphics
import Foundation

struct MenuBarItem: Hashable, Identifiable {
    let windowID: CGWindowID
    let processID: pid_t
    let ownerName: String
    let frame: CGRect

    var id: CGWindowID { windowID }
}

import Foundation
import os

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.HiddenBar.demo.HiddenBar"

    static let app = os.Logger(subsystem: subsystem, category: "app")
    static let menuBar = os.Logger(subsystem: subsystem, category: "menubar")
    static let capture = os.Logger(subsystem: subsystem, category: "capture")
    static let panel = os.Logger(subsystem: subsystem, category: "panel")
    static let events = os.Logger(subsystem: subsystem, category: "events")
    static let permissions = os.Logger(subsystem: subsystem, category: "permissions")
}

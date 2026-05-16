import OSLog

struct Logger {
    private let base: os.Logger

    init(category: String) {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.HiddenBar.demo.HiddenBar"
        self.base = os.Logger(subsystem: subsystem, category: category)
    }

    func info(_ message: String) {
        base.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        base.debug("\(message, privacy: .public)")
    }

    func notice(_ message: String) {
        base.notice("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        base.error("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        base.warning("\(message, privacy: .public)")
    }
}

extension Logger {
    static let app = Logger(category: "app")
    static let menuBar = Logger(category: "menubar")
    static let capture = Logger(category: "capture")
    static let panel = Logger(category: "panel")
    static let events = Logger(category: "events")
    static let permissions = Logger(category: "permissions")
}

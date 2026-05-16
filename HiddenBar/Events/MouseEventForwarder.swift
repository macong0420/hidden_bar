import AppKit
import CoreGraphics

@MainActor
final class MouseEventForwarder {
    private let eventSource: CGEventSource?

    init() {
        self.eventSource = CGEventSource(stateID: .hidSystemState)
    }

    func forwardClick(at point: CGPoint) {
        guard let source = eventSource else {
            Logger.events.error("CGEventSource unavailable; cannot forward click.")
            return
        }

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            Logger.events.error("Failed to synthesize click events at \(String(describing: point)).")
            return
        }

        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

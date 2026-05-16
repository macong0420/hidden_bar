import AppKit
import ApplicationServices
import Combine
import CoreGraphics

@MainActor
final class PermissionsManager {
    @Published private(set) var screenCaptureAuthorized: Bool = false
    @Published private(set) var accessibilityAuthorized: Bool = false

    private var refreshTimer: DispatchSourceTimer?
    private var didRequestScreenCapture = false

    func bootstrap() {
        refresh()
        if !screenCaptureAuthorized {
            requestScreenCapture()
        }
        if !accessibilityAuthorized {
            requestAccessibility(prompt: true)
        }
        startMonitoring()
    }

    func refresh() {
        screenCaptureAuthorized = CGPreflightScreenCaptureAccess()
        accessibilityAuthorized = AXIsProcessTrusted()
    }

    func requestScreenCapture() {
        guard !didRequestScreenCapture else { return }
        didRequestScreenCapture = true
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
    }

    func requestAccessibility(prompt: Bool) {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options: CFDictionary = [key: prompt] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        accessibilityAuthorized = granted
    }

    private func startMonitoring() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        timer.resume()
        refreshTimer = timer
    }
}

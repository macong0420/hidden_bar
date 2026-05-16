import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class MenuBarItemImageCapture {
    private struct CacheKey: Hashable {
        let windowID: CGWindowID
        let widthBucket: Int
    }

    private var cache: [CacheKey: CGImage] = [:]
    private let backingScale: CGFloat

    init(backingScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2) {
        self.backingScale = backingScale
    }

    func clearCache() {
        cache.removeAll()
    }

    func captureImages(for items: [MenuBarItem]) async -> [CGWindowID: CGImage] {
        guard !items.isEmpty else { return [:] }

        var results: [CGWindowID: CGImage] = [:]
        for item in items {
            if let cached = cache[Self.makeKey(item: item)] {
                results[item.windowID] = cached
            }
        }

        let missing = items.filter { results[$0.windowID] == nil }
        guard !missing.isEmpty else { return results }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            for item in missing {
                guard let window = content.windows.first(where: { $0.windowID == item.windowID }) else {
                    Logger.capture.debug("Missing SCWindow for \(item.windowID, privacy: .public) — likely permission gap.")
                    continue
                }
                if let image = await captureSingle(window: window, item: item) {
                    cache[Self.makeKey(item: item)] = image
                    results[item.windowID] = image
                }
            }
        } catch {
            Logger.capture.error("SCShareableContent failed: \(error.localizedDescription, privacy: .public)")
        }

        return results
    }

    private func captureSingle(window: SCWindow, item: MenuBarItem) async -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int((item.frame.width * backingScale).rounded(.up))
        configuration.height = Int((item.frame.height * backingScale).rounded(.up))
        configuration.scalesToFit = true
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.capturesShadowsOnly = false

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            Logger.capture.error("Capture failed for windowID \(item.windowID): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func makeKey(item: MenuBarItem) -> CacheKey {
        CacheKey(windowID: item.windowID, widthBucket: Int(item.frame.width.rounded()))
    }
}
